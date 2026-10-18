import uuid
from datetime import timedelta
from unittest.mock import patch
from django.contrib.auth.models import User
from django.core import mail
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from .models import UserProfile, Device, DrivingSession, DrowsinessEvent
from . import monitoring


class AccountAndOwnershipTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("driver", "driver@example.com", "SafeRoad!27")
        self.other = User.objects.create_user("other", "other@example.com", "OtherRoad!27")
        UserProfile.objects.create(user=self.user)
        UserProfile.objects.create(user=self.other)
        self.device = Device.objects.create(user=self.user, name="Pi", device_id="DRIVEALERT-PI-001")
        self.other_device = Device.objects.create(user=self.other, name="Other", device_id="OTHER")
        self.session = DrivingSession.objects.create(user=self.user, device=self.device, start_time=timezone.now())
        self.other_session = DrivingSession.objects.create(user=self.other, device=self.other_device, start_time=timezone.now())
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_registration_saves_profile_and_hashes_password(self):
        self.client.force_authenticate(None)
        response = self.client.post("/api/auth/register/", {"username": "new@example.com", "email": "new@example.com",
            "password": "NightRoad!27", "full_name": "New Driver", "vehicle_model": "Myvi"}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        user = User.objects.get(username="new@example.com")
        self.assertTrue(user.check_password("NightRoad!27"))
        self.assertEqual(user.profile.vehicle_model, "Myvi")
        self.assertNotIn("password", response.data)

    def test_registration_rejects_duplicate_email_and_weak_password(self):
        response = self.client.post("/api/auth/register/", {"username":"new", "email":"DRIVER@example.com", "password":"12345678"}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_email_login(self):
        self.client.force_authenticate(None)
        response = self.client.post("/api/auth/login/", {"username":"DRIVER@example.com", "password":"SafeRoad!27"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)

    def test_anonymous_cannot_access_monitor(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get("/api/monitor/api/status").status_code, 401)

    def test_session_create_and_update_cannot_use_another_users_device(self):
        response = self.client.post("/api/sessions/", {"device":self.other_device.pk, "start_time":timezone.now().isoformat()}, format="json")
        self.assertEqual(response.status_code, 400)
        response = self.client.patch(f"/api/sessions/{self.session.pk}/", {"device":self.other_device.pk}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_event_update_cannot_move_to_another_users_session(self):
        event = DrowsinessEvent.objects.create(session=self.session, event_type="microsleep", timestamp=timezone.now())
        response = self.client.patch(f"/api/events/{event.pk}/", {"session":self.other_session.pk}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(self.client.get(f"/api/sessions/{self.other_session.pk}/").status_code, 404)

    def test_invalid_duration_and_time(self):
        response = self.client.post("/api/events/", {"session":self.session.pk, "event_type":"microsleep",
            "timestamp":timezone.now().isoformat(), "duration":-1}, format="json")
        self.assertEqual(response.status_code, 400)
        response = self.client.patch(f"/api/sessions/{self.session.pk}/",
            {"end_time": (self.session.start_time-timedelta(seconds=1)).isoformat()}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_profile_and_email_update_is_validated_before_saving(self):
        response = self.client.patch("/api/profile/", {"full_name":"Changed", "email":"other@example.com"}, format="json")
        self.assertEqual(response.status_code, 400)
        self.user.profile.refresh_from_db()
        self.assertEqual(self.user.profile.full_name, "")
        response = self.client.patch("/api/profile/", {"full_name":"Driver Name", "vehicle_model":"Axia", "email":"updated@example.com"}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, "updated@example.com")
        self.assertEqual(self.user.profile.vehicle_model, "Axia")

    def test_active_device_cannot_be_deleted(self):
        self.assertEqual(self.client.delete(f"/api/devices/{self.device.pk}/").status_code, 400)

    def test_password_reset_email_and_one_time_link(self):
        self.client.force_authenticate(None)
        response = self.client.post("/api/auth/password-reset/", {"email":"driver@example.com"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)
        url = mail.outbox[0].body.splitlines()[-1]
        response = self.client.post(url, {"password":"UpdatedRoad!42", "confirm":"UpdatedRoad!42"})
        self.assertContains(response, "Password updated")
        self.assertContains(self.client.get(url), "invalid or has expired")

    def test_change_password_requires_current_password(self):
        bad = self.client.post("/api/auth/change-password/", {"current_password":"bad", "new_password":"UpdatedRoad!42"}, format="json")
        self.assertEqual(bad.status_code, 400)
        good = self.client.post("/api/auth/change-password/", {"current_password":"SafeRoad!27", "new_password":"UpdatedRoad!42"}, format="json")
        self.assertEqual(good.status_code, 200)

    @patch("api.monitoring.sync_user", return_value=None)
    def test_analytics_period_filters_and_active_duration(self, _):
        DrowsinessEvent.objects.create(session=self.session, event_type="microsleep", timestamp=timezone.now())
        DrowsinessEvent.objects.create(session=self.session, event_type="microsleep", timestamp=timezone.now()-timedelta(days=45))
        response = self.client.get("/api/analytics/summary/?period=Today")
        self.assertEqual(response.data["total_microsleeps"], 1)
        self.assertGreaterEqual(response.data["total_driving_duration_seconds"], 0)
        self.assertIn("recommendation", response.data)


class DeviceSyncTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("driver", password="SafeRoad!27")
        UserProfile.objects.create(user=self.user)
        self.device = Device.objects.create(user=self.user, name="Pi", device_id="DRIVEALERT-PI-001")
        self.run = uuid.uuid4()
        self.session = DrivingSession.objects.create(user=self.user, device=self.device,
            start_time=timezone.now()-timedelta(seconds=5), device_run_id=self.run)

    @patch("api.monitoring.device_request")
    def test_sync_retries_do_not_duplicate_events_and_close_session(self, transport):
        event_id = str(uuid.uuid4())
        transport.return_value.json.return_value = {"run_id":str(self.run), "ended_at":timezone.now().timestamp(),
            "events":[{"id":event_id, "event_type":"microsleep", "timestamp":timezone.now().timestamp(), "duration":0.8, "ear_value":0.13}]}
        monitoring.sync_session(self.session)
        monitoring.sync_session(self.session)
        self.assertEqual(DrowsinessEvent.objects.count(), 1)
        self.session.refresh_from_db()
        self.assertIsNotNone(self.session.end_time)

    @patch("api.monitoring.device_request")
    def test_wrong_run_snapshot_is_rejected(self, transport):
        transport.return_value.json.return_value = {"run_id":str(uuid.uuid4()), "events":[]}
        with self.assertRaises(monitoring.DeviceUnavailable):
            monitoring.sync_session(self.session)
        self.assertEqual(DrowsinessEvent.objects.count(), 0)

    @patch("api.monitoring.device_request", side_effect=monitoring.DeviceUnavailable())
    def test_outage_preserves_pending_session_for_retry(self, _):
        with self.assertRaises(monitoring.DeviceUnavailable):
            monitoring.start(self.user)
        self.assertEqual(DrivingSession.objects.filter(end_time__isnull=True).count(), 1)

    @patch("api.monitoring.device_request")
    def test_stop_synchronises_before_reporting_success(self, transport):
        def response(method, path, data=None):
            from unittest.mock import Mock
            result = Mock()
            result.json.return_value = {"run_id":str(self.run), "events":[], "ended_at":timezone.now().timestamp()}
            return result
        transport.side_effect = response
        monitoring.stop(self.user)
        self.session.refresh_from_db()
        self.assertIsNotNone(self.session.end_time)

    def test_another_user_cannot_control_pi(self):
        other = User.objects.create_user("other")
        with self.assertRaises(monitoring.PermissionDenied):
            monitoring.registered_device(other)

# These protocol tests also exercise the actual Flask routes when Flask is installed.
import importlib.util
import os
import sys
import unittest
from pathlib import Path

@unittest.skipUnless(importlib.util.find_spec("flask"), "Install device requirements to run Pi protocol integration tests.")
class FullMonitoringProtocolTests(TestCase):
    def setUp(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "DriveAlert Device"))
        import device
        from journal import Journal
        import tempfile
        self.device = device
        self.temp = tempfile.TemporaryDirectory()
        device.journal = Journal(Path(self.temp.name) / "journal.db")
        device.thread = None
        device.state.update(run_id=None, monitoring=False)
        os.environ["DEVICE_API_KEY"] = "integration-key"
        self.user = User.objects.create_user("integrated", password="RoadAhead!42")
        UserProfile.objects.create(user=self.user)
        Device.objects.create(user=self.user, name="Pi", device_id="DRIVEALERT-PI-001")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def tearDown(self):
        self.device.stop_event.set()
        if self.device.thread:
            self.device.thread.join(2)
        self.device.journal.db.close()
        self.temp.cleanup()

    def bridge(self, method, path, data=None):
        response = self.device.app.test_client().open(path, method=method, json=data, headers={"X-Device-Key":"integration-key"})
        if response.status_code >= 400:
            raise monitoring.DeviceUnavailable(response.get_json().get("message"))
        class Result:
            content = response.data
            def json(self):
                return response.get_json()
        return Result()

    def loop(self, run_id):
        self.device.journal.event(run_id, "microsleep", 0.9, 0.12)
        self.device.state.update(camera=True, calibrating=False, status="Monitoring")
        self.device.ready_event.set()
        self.device.stop_event.wait(3)
        self.device.journal.end(run_id)
        self.device.state.update(camera=False, monitoring=False, status="Stopped")

    def test_start_navigate_retry_stop_and_report_use_same_session(self):
        with patch("api.monitoring.device_request", side_effect=self.bridge), patch.object(self.device, "monitoring_loop", self.loop):
            first = self.client.post("/api/monitor/api/monitor/start", {}, format="json")
            self.assertEqual(first.status_code, 200, first.data)
            second = self.client.post("/api/monitor/api/monitor/start", {}, format="json")
            self.assertEqual(second.status_code, 200, second.data)
            self.assertEqual(first.data["session_id"], second.data["session_id"])
            self.assertEqual(self.client.get("/api/events/").data[0]["event_type"], "microsleep")
            stopped = self.client.post("/api/monitor/api/monitor/stop", {}, format="json")
            self.assertEqual(stopped.status_code, 200, stopped.data)
            self.assertEqual(DrivingSession.objects.count(), 1)
            self.assertEqual(DrowsinessEvent.objects.count(), 1)
            self.assertIsNotNone(DrivingSession.objects.get().end_time)
            self.assertEqual(self.client.get("/api/analytics/summary/").data["total_microsleeps"], 1)

    def test_initialisation_failure_closes_run_and_allows_new_start(self):
        def failure(run_id):
            self.device.state.update(monitoring=False, error="Camera unavailable")
            self.device.journal.end(run_id)
            self.device.ready_event.set()
        with patch("api.monitoring.device_request", side_effect=self.bridge), patch.object(self.device, "monitoring_loop", failure):
            response = self.client.post("/api/monitor/api/monitor/start", {}, format="json")
            self.assertEqual(response.status_code, 503)
            self.assertEqual(DrivingSession.objects.filter(end_time__isnull=True).count(), 0)


