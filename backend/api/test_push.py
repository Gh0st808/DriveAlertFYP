import uuid
from datetime import timedelta
from unittest.mock import patch
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from .models import UserProfile, Device, DrivingSession, DrowsinessEvent, PushRegistration, PushDelivery
from . import push

@override_settings(FIREBASE_ENABLED=True, GOOGLE_APPLICATION_CREDENTIALS="not-used-in-mocked-tests.json", DEVICE_API_KEY="test-device-key")
class PushTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("push-user", password="SafeRoad!42")
        self.other = User.objects.create_user("other-push", password="SafeRoad!42")
        UserProfile.objects.create(user=self.user, push_notifications_enabled=True)
        UserProfile.objects.create(user=self.other, push_notifications_enabled=True)
        device = Device.objects.create(user=self.user, name="Pi", device_id="DRIVEALERT-PI-001")
        self.session = DrivingSession.objects.create(user=self.user, device=device, start_time=timezone.now(), device_run_id=uuid.uuid4())
        self.registration = PushRegistration.objects.create(user=self.user, token="example-device-registration-token-long-enough")
        self.event = DrowsinessEvent.objects.create(session=self.session, source_id=uuid.uuid4(),
            event_type="microsleep", timestamp=timezone.now(), duration=0.8, ear_value=0.12)
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_registration_is_authenticated_and_bound_to_current_account(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.post("/api/notifications/registration/", {"token":"another-device-token-long-enough"}).status_code, 401)
        self.client.force_authenticate(self.other)
        response = self.client.post("/api/notifications/registration/", {"token":self.registration.token}, format="json")
        self.assertEqual(response.status_code, 200)
        self.registration.refresh_from_db()
        self.assertEqual(self.registration.user_id, self.other.pk)

    def test_token_deletion_cannot_remove_another_accounts_registration(self):
        self.client.force_authenticate(self.other)
        self.client.delete("/api/notifications/registration/", {"token":self.registration.token}, format="json")
        self.assertTrue(PushRegistration.objects.filter(pk=self.registration.pk).exists())

    def test_queue_is_idempotent(self):
        push.enqueue(self.event)
        push.enqueue(self.event)
        self.assertEqual(PushDelivery.objects.count(), 1)

    @patch("firebase_admin.messaging.send", return_value="test-message")
    @patch("firebase_admin.get_app", return_value=object())
    def test_push_selects_the_android_alert_channel(self, app, sender):
        push.send_notification(self.registration, self.event)
        message = sender.call_args.args[0]
        self.assertEqual(message.android.notification.channel_id, "drivealert_alerts_v2")
        self.assertEqual(message.android.priority, "high")

    def test_old_events_and_drowsiness_do_not_create_push_jobs(self):
        self.event.timestamp = timezone.now()-timedelta(hours=1)
        push.enqueue(self.event)
        self.event.timestamp = timezone.now()
        self.event.event_type = "drowsiness"
        push.enqueue(self.event)
        self.assertEqual(PushDelivery.objects.count(), 0)

    @patch("api.push.send_notification")
    def test_opt_out_cancels_queued_delivery(self, sender):
        push.enqueue(self.event)
        UserProfile.objects.filter(user=self.user).update(push_notifications_enabled=False)
        push.process_one()
        self.assertEqual(PushDelivery.objects.get().status, "cancelled")
        sender.assert_not_called()

    @patch("api.push.send_notification")
    def test_account_switch_cancels_old_accounts_job(self, sender):
        push.enqueue(self.event)
        self.registration.user = self.other
        self.registration.save()
        push.process_one()
        self.assertEqual(PushDelivery.objects.get().status, "cancelled")
        sender.assert_not_called()

    @patch("api.push.send_notification", return_value="firebase-message-id")
    def test_success_is_saved_and_not_sent_again(self, sender):
        push.enqueue(self.event)
        self.assertTrue(push.process_one())
        self.assertFalse(push.process_one())
        job = PushDelivery.objects.get()
        self.assertEqual(job.status, "sent")
        self.assertIsNotNone(job.sent_at)
        sender.assert_called_once()

    @patch("api.push.send_notification", side_effect=OSError("private contents must not be stored"))
    def test_failure_is_retried_without_logging_sensitive_error_body(self, sender):
        push.enqueue(self.event)
        push.process_one()
        job = PushDelivery.objects.get()
        self.assertEqual(job.status, "pending")
        self.assertEqual(job.last_error, "OSError")
        self.assertGreater(job.next_attempt, timezone.now())

    def payload(self):
        return {"run_id":str(self.session.device_run_id), "event":{
            "id":str(uuid.uuid4()), "event_type":"microsleep", "timestamp":timezone.now().timestamp(),
            "duration":0.8, "ear_value":0.12}}

    def test_pi_upload_requires_key_and_valid_run(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.post("/api/device/events/", self.payload(), format="json").status_code, 403)
        data = self.payload()
        data["run_id"] = str(uuid.uuid4())
        self.assertEqual(self.client.post("/api/device/events/", data, format="json", HTTP_X_DEVICE_KEY="test-device-key").status_code, 404)

    def test_duplicate_pi_upload_creates_one_record_and_one_push_job(self):
        data = self.payload()
        with self.captureOnCommitCallbacks(execute=True):
            first = self.client.post("/api/device/events/", data, format="json", HTTP_X_DEVICE_KEY="test-device-key")
        with self.captureOnCommitCallbacks(execute=True):
            second = self.client.post("/api/device/events/", data, format="json", HTTP_X_DEVICE_KEY="test-device-key")
        self.assertEqual(first.status_code, 201, first.data)
        self.assertEqual(second.status_code, 200, second.data)
        self.assertEqual(DrowsinessEvent.objects.filter(source_id=data["event"]["id"]).count(), 1)
        self.assertEqual(PushDelivery.objects.count(), 1)

    def test_future_clock_and_invalid_numbers_are_rejected(self):
        data = self.payload()
        data["event"]["timestamp"] = (timezone.now()+timedelta(hours=1)).timestamp()
        self.assertEqual(self.client.post("/api/device/events/", data, format="json", HTTP_X_DEVICE_KEY="test-device-key").status_code, 400)
        data = self.payload()
        data["event"]["duration"] = -1
        self.assertEqual(self.client.post("/api/device/events/", data, format="json", HTTP_X_DEVICE_KEY="test-device-key").status_code, 400)

    @patch("api.push.send_notification", return_value="test-message")
    def test_explicit_test_notification_does_not_create_fake_detection(self, sender):
        response = self.client.post("/api/notifications/test/", {"token":self.registration.token}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(DrowsinessEvent.objects.count(), 1)
        self.assertTrue(sender.call_args.kwargs["test"])

