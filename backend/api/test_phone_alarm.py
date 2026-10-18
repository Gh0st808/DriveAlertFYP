import time
import uuid
from types import SimpleNamespace
from unittest.mock import patch
from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from .models import Device, DrivingSession, UserProfile
from .phone_alarm import token_for, MAX_AGE
from .monitor_views import with_phone_alarm


class PhoneAlarmTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("phone-driver", password="SafeRoad!42")
        self.profile = UserProfile.objects.create(user=self.user)
        self.device = Device.objects.create(user=self.user, device_id="DRIVEALERT-PI-001", name="Pi")
        self.session = DrivingSession.objects.create(user=self.user, device=self.device,
            start_time=timezone.now(), device_run_id=uuid.uuid4())
        self.token = token_for(self.session)
        self.client = APIClient()
        self.state = {"run_id": str(self.session.device_run_id), "monitoring": True,
            "driver_detected": True, "calibrating": False, "microsleep_active": True,
            "sample_age_seconds": 0, "alarm_event_age_seconds": 0,
            "last_alarm_event": {"id": "fresh-warning", "event_type": "microsleep", "timestamp": timezone.now().timestamp()}}

    def request(self, token=None):
        return self.client.get("/api/monitor/phone-alarm/", HTTP_AUTHORIZATION="Monitor " + (token or self.token))

    def transport(self):
        return patch("api.phone_alarm.monitoring.device_request", return_value=SimpleNamespace(json=lambda: self.state))

    def test_capability_is_required_and_cannot_be_tampered_with(self):
        self.assertIn(self.client.get("/api/monitor/phone-alarm/").status_code, (401, 403))
        self.assertIn(self.request(self.token + "changed").status_code, (401, 403))

    def test_capability_only_reads_minimal_alarm_status_not_account_endpoints(self):
        with self.transport():
            response = self.request()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["microsleep_active"])
        self.assertEqual(response.data["alarm_event_id"], "fresh-warning")
        self.assertNotIn("phone_alarm_token", response.data)
        self.assertNotIn("password", str(response.data))
        self.assertEqual(self.client.get("/api/auth/me/", HTTP_AUTHORIZATION="Monitor " + self.token).status_code, 401)

    def test_sound_setting_is_read_live_and_does_not_depend_on_firebase(self):
        self.profile.alert_sound_enabled = False
        self.profile.save()
        with self.transport():
            self.assertFalse(self.request().data["sound_enabled"])

    def test_old_events_are_not_replayed_but_current_closure_remains_active(self):
        self.state["alarm_event_age_seconds"] = 60
        with self.transport():
            response = self.request()
        self.assertEqual(response.data["alarm_event_id"], "")
        self.assertTrue(response.data["microsleep_active"])

    def test_stalled_camera_does_not_report_a_live_alarm(self):
        self.state["sample_age_seconds"] = 20
        with self.transport():
            self.assertEqual(self.request().status_code, 503)

    def test_visibility_warning_reaches_phone_without_becoming_a_microsleep(self):
        self.state.update(visibility_warning=True, driver_detected=False,
                          microsleep_active=False, last_alarm_event=None)
        with self.transport():
            response = self.request()
        self.assertTrue(response.data["visibility_warning"])
        self.assertFalse(response.data["microsleep_active"])
        self.assertEqual(response.data["alarm_event_id"], "")

    def test_stopped_session_and_wrong_run_cannot_keep_alarm_alive(self):
        with self.transport():
            self.state["run_id"] = str(uuid.uuid4())
            self.assertFalse(self.request().data["monitoring"])
        self.session.end_time = timezone.now()
        self.session.save()
        with patch("api.phone_alarm.monitoring.device_request") as transport:
            self.assertFalse(self.request().data["monitoring"])
            transport.assert_not_called()

    def test_device_reassignment_revokes_journey_access(self):
        other = User.objects.create_user("other-driver")
        self.device.user = other
        self.device.save()
        with patch("api.phone_alarm.monitoring.device_request") as transport:
            self.assertFalse(self.request().data["monitoring"])
            transport.assert_not_called()

    def test_password_change_and_expiry_revoke_capability(self):
        with patch("django.core.signing.time.time", return_value=time.time() + MAX_AGE + 1):
            self.assertIn(self.request().status_code, (401, 403))
        self.user.set_password("ChangedRoad!42")
        self.user.save()
        self.assertIn(self.request().status_code, (401, 403))

    def test_monitor_status_only_issues_token_for_owned_active_run(self):
        result = with_phone_alarm(self.user, {"monitoring": True, "run_id": str(self.session.device_run_id)})
        self.assertIn("phone_alarm_token", result)
        other = User.objects.create_user("not-owner")
        result = with_phone_alarm(other, {"monitoring": True, "run_id": str(self.session.device_run_id)})
        self.assertNotIn("phone_alarm_token", result)
