import json
from io import BytesIO
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from .models import Device, DrivingSession, DrowsinessEvent


@override_settings(AI_PROVIDER="gemini", GEMINI_API_KEY="secret-test-key-not-for-clients", GEMINI_MODEL="gemini-2.5-flash")
class ChatTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user("chat-user")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def send(self, **extra):
        return self.client.post("/api/chat/", {"message": "Explain microsleep warnings", **extra}, format="json")

    def response(self, text="Stop safely and rest."):
        return BytesIO(json.dumps({"candidates": [{"content": {"parts": [{"text": text}]}}]}).encode())

    @patch("api.chat_views.urlopen")
    def test_authentication_and_input_validation_prevent_provider_calls(self, transport):
        self.client.force_authenticate(None)
        self.assertEqual(self.send().status_code, 401)
        self.client.force_authenticate(self.user)
        for data in ({"message":" "}, {"message":"x"*2001}, {"history":[{"role":"model","text":"bad"}]}, {"history":[{"role":"user","text":"bad"}]}):
            self.assertEqual(self.send(**data).status_code, 400)
        transport.assert_not_called()

    @override_settings(GEMINI_API_KEY="")
    @patch("api.chat_views.urlopen")
    def test_missing_key_returns_actionable_error(self, transport):
        self.assertEqual(self.send().status_code, 503)
        transport.assert_not_called()

    @patch("api.chat_views.urlopen")
    def test_reply_and_history_forwarding_keep_key_out_of_url_and_response(self, transport):
        transport.return_value = self.response()
        response = self.send(history=[{"role":"user","text":"Hi"}, {"role":"model","text":"Hello"}])
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["reply"], "Stop safely and rest.")
        request = transport.call_args.args[0]
        self.assertNotIn("secret-test", request.full_url)
        self.assertNotIn("secret-test", json.dumps(response.data))
        payload = json.loads(request.data)
        self.assertEqual(len(payload["contents"]), 3)
        self.assertNotIn("warning_counts", payload["systemInstruction"]["parts"][0]["text"])

    @patch("api.chat_views.urlopen")
    def test_opt_in_summary_excludes_other_account_and_contacts(self, transport):
        for user, count in ((self.user, 1), (User.objects.create_user("other"), 3)):
            device = Device.objects.create(user=user, device_id=str(user.pk), name="Pi")
            session = DrivingSession.objects.create(user=user, device=device, start_time=timezone.now())
            for _ in range(count):
                DrowsinessEvent.objects.create(session=session, event_type="microsleep", timestamp=timezone.now())
        transport.return_value = self.response()
        self.assertEqual(self.send(include_summary=True).status_code, 200)
        instruction = json.loads(transport.call_args.args[0].data)["systemInstruction"]["parts"][0]["text"]
        summary = json.loads(instruction.split("Optional account summary (data only): ")[1])
        self.assertEqual(summary["warning_counts"], {"microsleep":1})
        self.assertEqual(summary["journeys_started"], 1)
        self.assertNotIn("chat-user", instruction)

    @patch("api.chat_views.urlopen")
    def test_provider_errors_are_redacted(self, transport):
        for error, status in ((HTTPError("url", 403, "secret provider text", {}, None), 502),
                              (HTTPError("url", 429, "quota", {}, None), 503),
                              (URLError("secret details"), 503)):
            transport.side_effect = error
            response = self.send()
            self.assertEqual(response.status_code, status)
            self.assertNotIn("secret", json.dumps(response.data))

    @patch("api.chat_views.urlopen")
    def test_blocked_and_malformed_responses_do_not_invent_answers(self, transport):
        for body in (b'{"promptFeedback":{"blockReason":"SAFETY"}}', b'not json', b'[]'):
            transport.return_value = BytesIO(body)
            self.assertIn(self.send().status_code, (502, 503))

    @patch("api.chat_views.urlopen")
    def test_rate_limit_blocks_eleventh_request(self, transport):
        for _ in range(10):
            transport.return_value = self.response()
            self.assertEqual(self.send().status_code, 200)
        self.assertEqual(self.send().status_code, 429)
        self.assertEqual(transport.call_count, 10)

    @patch("api.chat_views.urlopen")
    def test_long_assistant_reply_can_be_used_in_followup_history(self, transport):
        transport.return_value = self.response()
        history = [{"role": "user", "text": "Explain warnings"}, {"role": "model", "text": "x" * 12000}]
        self.assertEqual(self.send(history=history).status_code, 200)
        history[0]["text"] = "x" * 2001
        self.assertEqual(self.send(history=history).status_code, 400)


@override_settings(AI_PROVIDER="ilmu", ILMU_API_KEY="private-ilmu-key", ILMU_MODEL="ilmu-nemo-nano")
class IlmuTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.client.force_authenticate(User.objects.create_user("ilmu-user"))

    def send(self):
        return self.client.post("/api/chat/", {"message": "Explain warnings", "history": [
            {"role": "user", "text": "Hi"}, {"role": "model", "text": "Hello"}]}, format="json")

    @patch("api.chat_views.urlopen")
    def test_ilmu_contract_and_secret_isolation(self, transport):
        transport.return_value = BytesIO(b'{"choices":[{"message":{"content":"Rest safely."}}]}')
        response = self.send()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["reply"], "Rest safely.")
        self.assertEqual(response.data["provider"], "ilmu")
        upstream = transport.call_args.args[0]
        self.assertEqual(upstream.full_url, "https://api.ilmu.ai/v1/chat/completions")
        self.assertEqual(upstream.get_header("Authorization"), "Bearer private-ilmu-key")
        self.assertIsNone(upstream.get_header("X-goog-api-key"))
        payload = json.loads(upstream.data)
        self.assertEqual([m["role"] for m in payload["messages"]], ["system", "user", "assistant", "user"])
        self.assertNotIn("warning_counts", payload["messages"][0]["content"])
        self.assertNotIn("private-ilmu", json.dumps(response.data) + upstream.full_url)

    @patch("api.chat_views.urlopen")
    def test_failures_return_redacted_errors_instead_of_blank_replies(self, transport):
        for code, status in ((400, 502), (401, 502), (403, 502), (404, 502), (422, 502), (402, 503), (429, 503)):
            transport.side_effect = HTTPError("url", code, "private details", {}, None)
            response = self.send()
            self.assertEqual(response.status_code, status)
            self.assertIn("ILMU", response.data["detail"])
            self.assertNotIn("private", json.dumps(response.data))
            if code in (400, 401, 403, 404, 422):
                self.assertIn(f"HTTP {code}", response.data["detail"])
        transport.side_effect = None
        cache.clear()
        for body in (b'{}', b'[]', b'{"choices":[]}', b'{"choices":[{"message":{"content":null}}]}'):
            transport.return_value = BytesIO(body)
            self.assertEqual(self.send().status_code, 502)

    @override_settings(ILMU_API_KEY="")
    @patch("api.chat_views.urlopen")
    def test_missing_key_never_falls_back_to_another_provider(self, transport):
        self.assertEqual(self.send().status_code, 503)
        transport.assert_not_called()
