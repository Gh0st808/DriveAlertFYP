import os
import tempfile
import unittest
import uuid
from pathlib import Path
from detection import Detection, eye_aspect_ratio
from journal import Journal

class DetectionTests(unittest.TestCase):
    def calibrated(self):
        d = Detection()
        for i in range(50):
            state, events = d.update(0.3, i*0.1)
        self.assertAlmostEqual(d.baseline, 0.3)
        self.assertFalse(state["calibrating"])
        self.assertEqual(events, [])
        return d

    def test_calibration_then_single_event_per_sustained_closure(self):
        d = self.calibrated()
        events = []
        for i in range(100):
            state, emitted = d.update(0.1, 10+i*0.1)
            events += emitted
        self.assertEqual([e[0] for e in events].count("microsleep"), 1)
        self.assertEqual([e[0] for e in events].count("drowsiness"), 1)
        self.assertEqual([e[0] for e in events].count("long_closure"), 1)
        d.update(0.3, 21)
        d.update(0.1, 22)
        _, events = d.update(0.1, 23)
        self.assertIn("microsleep", [e[0] for e in events])

    def test_face_loss_resets_timers(self):
        d = self.calibrated()
        d.update(0.1, 10)
        d.update(0, 11, valid=False)
        _, events = d.update(0.1, 12)
        self.assertEqual(events, [])

    def test_blink_does_not_count_as_microsleep(self):
        d = self.calibrated()
        d.update(0.1, 10)
        d.update(0.3, 10.2)
        self.assertEqual(d.blinks, 1)
        self.assertEqual(d.microsleeps, 0)

    def test_closed_eyes_do_not_calibrate(self):
        d = Detection()
        for i in range(100):
            d.update(0.1, i)
        self.assertEqual(d.baseline, 0)

    def test_ear_zero_horizontal(self):
        self.assertEqual(eye_aspect_ratio([(0,0)]*6), 0)

    def test_phone_alarm_state_only_activates_at_microsleep_threshold(self):
        d = self.calibrated()
        d.update(0.1, 10)
        state, _ = d.update(0.1, 10.6)
        self.assertTrue(state["drowsy"])
        self.assertFalse(state["microsleep_active"])
        state, _ = d.update(0.1, 10.9)
        self.assertTrue(state["microsleep_active"])
        state, _ = d.update(0.3, 11)
        self.assertFalse(state["microsleep_active"])

    def test_face_loss_and_calibration_never_claim_current_microsleep(self):
        state, _ = Detection().update(0.3, 1)
        self.assertFalse(state["microsleep_active"])
        d = self.calibrated()
        d.update(0.1, 10)
        state, _ = d.update(0.1, 11)
        self.assertTrue(state["microsleep_active"])
        state, _ = d.update(0, 12, valid=False)
        self.assertFalse(state["microsleep_active"])

class JournalTests(unittest.TestCase):
    def test_persistence_recovery_and_metadata_only(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"events.db"
            journal = Journal(path)
            run = str(uuid.uuid4())
            journal.start(run)
            journal.event(run, "microsleep", 0.8, 0.13)
            journal.heartbeat(run)
            journal.db.close()
            restarted = Journal(path)
            recovered = restarted.get(run)
            restarted.db.close()
            self.assertIsNotNone(recovered["ended_at"])
            self.assertEqual(len(recovered["events"]), 1)
            self.assertNotIn("frame", str(recovered))

class DeviceApiTests(unittest.TestCase):
    def setUp(self):
        os.environ["DEVICE_API_KEY"] = "test-device-key"
        import device
        self.device = device
        self.directory = tempfile.TemporaryDirectory()
        device.journal = Journal(Path(self.directory.name)/"events.db")
        device.state["run_id"] = None
        self.client = device.app.test_client()

    def tearDown(self):
        self.device.journal.db.close()
        self.directory.cleanup()

    def test_authentication_required(self):
        self.assertEqual(self.client.get("/api/status").status_code, 401)
        self.assertEqual(self.client.get("/api/status", headers={"X-Device-Key":"test-device-key"}).status_code, 200)

    def test_run_validation_and_identity_protect_stop(self):
        headers={"X-Device-Key":"test-device-key"}
        self.assertEqual(self.client.post("/api/monitor/start", json={}, headers=headers).status_code, 400)
        self.device.state["run_id"] = str(uuid.uuid4())
        self.assertEqual(self.client.post("/api/monitor/stop", json={"run_id":str(uuid.uuid4())}, headers=headers).status_code, 409)


class EventSenderTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.journal = Journal(Path(self.directory.name)/"events.db")
        self.run = str(uuid.uuid4())
        self.journal.start(self.run)
        self.event = self.journal.event(self.run, "microsleep", 0.8, 0.12)

    def tearDown(self):
        self.journal.db.close()
        self.directory.cleanup()

    def test_success_acknowledges_outbox_without_deleting_history(self):
        from unittest.mock import patch, MagicMock
        from event_sender import send_pending
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b'{"saved":true}'
        with patch.dict(os.environ, {"BACKEND_URL":"http://backend/api", "DEVICE_API_KEY":"test-key"}), patch("event_sender.urlopen", return_value=response) as transport:
            send_pending(self.journal)
            send_pending(self.journal)
        self.assertEqual(transport.call_count, 1)
        self.assertEqual(self.journal.pending(), [])
        self.assertEqual(len(self.journal.get(self.run)["events"]), 1)

    def test_failure_defers_outbox_and_preserves_event(self):
        from unittest.mock import patch
        from event_sender import send_pending
        with patch.dict(os.environ, {"BACKEND_URL":"http://backend/api", "DEVICE_API_KEY":"test-key"}), patch("event_sender.urlopen", side_effect=OSError("offline")):
            send_pending(self.journal)
        self.assertEqual(self.journal.pending(), [])
        self.assertEqual(len(self.journal.get(self.run)["events"]), 1)
        self.assertEqual(self.journal.db.execute("SELECT sent FROM event_delivery").fetchone()[0], 0)

if __name__ == "__main__":
    unittest.main()
