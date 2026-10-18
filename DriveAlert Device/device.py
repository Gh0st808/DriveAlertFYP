"""DriveAlert Pi detection service. Phone audio is the default alert output."""
import hmac
import os
import threading
import time
import uuid
from pathlib import Path
from flask import Flask, Response, jsonify, request
from dotenv import load_dotenv
from detection import Detection, SENSITIVITY, eye_aspect_ratio
from journal import Journal

load_dotenv(Path(__file__).with_name(".env"))
app = Flask(__name__)
state_lock = threading.RLock()
control_lock = threading.RLock()
stop_event = threading.Event()
ready_event = threading.Event()
thread = None
journal = None
jpeg_frame = None
last_sample_tick = None
last_alarm_tick = None
state = {"monitoring": False, "camera": False, "driver_detected": False,
         "calibrating": False, "status": "Stopped", "run_id": None,
         "blink_count": 0, "drowsy_events": 0, "drowsy_count": 0,
         "microsleep_count": 0, "elapsed_seconds": 0, "session_duration": 0,
         "average_ear": 0, "baseline_ear": 0, "fps": 0,
         "eye_closed": False, "drowsy": False, "sensitivity_level": "Medium",
         "alert_sound_enabled": True, "audio_available": False, "last_event": None,
         "microsleep_active": False, "last_alarm_event": None, "alert_output": "phone"}


def get_journal():
    global journal
    if journal is None:
        journal = Journal(Path(os.getenv("DEVICE_JOURNAL", str(Path(__file__).with_name("events.sqlite3")))))
    return journal


@app.before_request
def authenticate():
    expected = os.getenv("DEVICE_API_KEY", "")
    if not expected or not hmac.compare_digest(request.headers.get("X-Device-Key", ""), expected):
        return jsonify(success=False, message="Device API key is missing or invalid."), 401


def monitoring_loop(run_id):
    global jpeg_frame, last_sample_tick, last_alarm_tick
    camera = landmarks = audio = None
    started = time.monotonic()
    fps_started = started
    frames = 0
    last_heartbeat = 0.0
    last_audio = 0.0
    detector = Detection(state["sensitivity_level"])
    try:
        import cv2
        from hardware import Camera, Landmarks, Audio
        camera = Camera()
        landmarks = Landmarks()
        audio = Audio() if os.getenv("PI_AUDIO_ENABLED", "false").lower() == "true" else None
        with state_lock:
            state.update(camera=True, audio_available=audio is not None and audio.mixer is not None, status="Calibrating")
        if audio and state["alert_sound_enabled"]:
            audio.play("camera_on.wav")
        ready_event.set()
        while not stop_event.is_set():
            frame = cv2.flip(camera.read(), 1)
            face = landmarks.find(frame)
            valid = face is not None
            ear = 0.0
            if face:
                valid = (max(x for x, _ in face) - min(x for x, _ in face) >= 120
                         and abs(face[263][0] - face[33][0]) >= 50)
                if valid:
                    ear = (eye_aspect_ratio([face[i] for i in [33,160,158,133,153,144]]) +
                           eye_aspect_ratio([face[i] for i in [362,385,387,263,373,380]])) / 2
            now = time.monotonic()
            detector.sensitivity = state["sensitivity_level"]
            result, events = detector.update(ear, now, valid)
            if face and not valid:
                result["status"] = "Move Closer"
            for event_type, duration, value in events:
                event = get_journal().event(run_id, event_type, duration, value)
                with state_lock:
                    state["last_event"] = event
                    if event_type in {"microsleep", "long_closure"}:
                        state["last_alarm_event"] = event
                        last_alarm_tick = now
            # Repeat an audible warning during a sustained closure without duplicating events.
            if audio and result["microsleep_active"] and state["alert_sound_enabled"] and now - last_audio >= 5:
                audio.play("alert_sound_1.mp3")
                last_audio = now
            frames += 1
            with state_lock:
                last_sample_tick = now
                state.update(result)
                state["session_duration"] = round(now - started, 1)
                state["elapsed_seconds"] = int(now - started)
                if now - fps_started >= 1:
                    state["fps"] = round(frames / (now - fps_started), 1)
                    fps_started = now
                    frames = 0
            if now - last_heartbeat >= 1:
                get_journal().heartbeat(run_id)
                last_heartbeat = now
            cv2.putText(frame, f"EAR: {ear:.3f}  {result['status']}", (15, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
            success, encoded = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 75])
            if success:
                with state_lock:
                    jpeg_frame = encoded.tobytes()
            if os.getenv("SHOW_PREVIEW", "false").lower() == "true":
                cv2.imshow("DriveAlert", frame)
                if cv2.waitKey(1) & 255 == ord("q"):
                    stop_event.set()
    except Exception as error:
        with state_lock:
            state["status"] = "Device Error"
            state["error"] = str(error)
        print("[DEVICE ERROR]", error, flush=True)
    finally:
        for resource in (landmarks, camera, audio):
            if resource:
                try:
                    resource.close()
                except Exception as error:
                    print("[CLEANUP]", error, flush=True)
        get_journal().end(run_id)
        with state_lock:
            state.update(monitoring=False, camera=False, driver_detected=False,
                         calibrating=False, eye_closed=False, drowsy=False, microsleep_active=False)
            if state["status"] != "Device Error":
                state["status"] = "Stopped"
            jpeg_frame = None
        ready_event.set()


@app.get("/api/status")
@app.get("/api/health")
def status():
    with state_lock:
        snapshot = dict(state)
        now = time.monotonic()
        snapshot["sample_age_seconds"] = now - last_sample_tick if last_sample_tick is not None else None
        snapshot["alarm_event_age_seconds"] = now - last_alarm_tick if last_alarm_tick is not None else None
        return jsonify(snapshot)


@app.get("/api/frame")
def frame():
    with state_lock:
        data = jpeg_frame
    if data is None:
        return jsonify(success=False, message="No current camera frame."), 503
    return Response(data, mimetype="image/jpeg", headers={"Cache-Control": "no-store"})


@app.get("/api/runs/<uuid:run_id>")
def run_snapshot(run_id):
    snapshot = get_journal().get(str(run_id))
    if snapshot is None:
        return jsonify(success=False, message="Run is not present on this Pi."), 404
    return jsonify(snapshot)


@app.patch("/api/settings")
def update_settings():
    data = request.get_json(silent=True) or {}
    if data.get("sensitivity", "Medium") not in SENSITIVITY:
        return jsonify(success=False, message="Sensitivity must be Low, Medium or High."), 400
    with state_lock:
        state["sensitivity_level"] = data.get("sensitivity", state["sensitivity_level"])
        state["alert_sound_enabled"] = data.get("alert_sound_enabled", state["alert_sound_enabled"]) is True
    return jsonify(success=True)


@app.post("/api/monitor/start")
def start():
    global thread, jpeg_frame, last_sample_tick, last_alarm_tick
    data = request.get_json(silent=True) or {}
    try:
        run_id = str(uuid.UUID(data.get("run_id", "")))
    except (ValueError, TypeError, AttributeError):
        return jsonify(success=False, message="A valid run_id is required."), 400
    if data.get("sensitivity", "Medium") not in SENSITIVITY:
        return jsonify(success=False, message="Invalid sensitivity."), 400
    with control_lock:
        if thread and thread.is_alive():
            if state["run_id"] == run_id:
                return jsonify(success=True, message="Monitoring is already running.")
            return jsonify(success=False, message="A different session is already running."), 409
        if get_journal().get(run_id) is not None:
            return jsonify(success=False, message="This run has ended. Start a new session."), 409
        get_journal().start(run_id)
        stop_event.clear()
        ready_event.clear()
        with state_lock:
            state.update(run_id=run_id, monitoring=True, camera=False, calibrating=True,
                         status="Starting", error=None, blink_count=0, drowsy_events=0,
                         drowsy_count=0, microsleep_count=0, long_closure_count=0,
                         elapsed_seconds=0, session_duration=0, baseline_ear=0, fps=0,
                          average_ear=0, last_event=None, last_alarm_event=None, microsleep_active=False,
                         sensitivity_level=data.get("sensitivity", "Medium"),
                         alert_sound_enabled=data.get("alert_sound_enabled", True) is True)
            jpeg_frame = None
            last_sample_tick = last_alarm_tick = None
        thread = threading.Thread(target=monitoring_loop, args=(run_id,), daemon=True)
        thread.start()
        if not ready_event.wait(8):
            return jsonify(success=True, message="Device is initialising. Check status.")
        if not state["monitoring"]:
            return jsonify(success=False, message=state.get("error", "Camera failed to start.")), 503
        return jsonify(success=True, message="Monitoring started.")


@app.post("/api/monitor/stop")
def stop():
    data = request.get_json(silent=True) or {}
    with control_lock:
        if state["run_id"] and data.get("run_id") != state["run_id"]:
            # An old run can already be ended; never stop a newer run accidentally.
            snapshot = get_journal().get(str(data.get("run_id")))
            if snapshot and snapshot["ended_at"] is not None:
                return jsonify(success=True, message="Run already ended.")
            return jsonify(success=False, message="Run identity does not match."), 409
        stop_event.set()
        if thread and thread.is_alive():
            thread.join(8)
            if thread.is_alive():
                return jsonify(success=False, message="Camera is still stopping. Retry Stop."), 503
        return jsonify(success=True, message="Monitoring stopped.")


if __name__ == "__main__":
    if not os.getenv("DEVICE_API_KEY"):
        raise SystemExit("Set DEVICE_API_KEY in .env before starting the device service.")
    get_journal()
    from event_sender import sender_loop
    sender_stop = threading.Event()
    threading.Thread(target=sender_loop, args=(get_journal(), sender_stop), daemon=True).start()
    try:
        from waitress import serve
        serve(app, host=os.getenv("DEVICE_BIND", "0.0.0.0"), port=5000, threads=4)
    finally:
        sender_stop.set()
        stop_event.set()
        if thread:
            thread.join(8)

