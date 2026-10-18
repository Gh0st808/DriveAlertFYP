"""Read-only, journey-scoped capability for the Android monitoring service."""
import hashlib
import hmac
import math
import time
from django.core import signing
from rest_framework.exceptions import AuthenticationFailed
from .models import DrivingSession, UserProfile
from . import monitoring

SALT = "drivealert.phone-alarm.v1"
MAX_AGE = 24 * 60 * 60

def password_stamp(user):
    return hashlib.sha256(user.password.encode()).hexdigest()

def token_for(session):
    return signing.dumps({"session": session.pk, "user": session.user_id,
        "run": str(session.device_run_id), "auth": password_stamp(session.user)}, salt=SALT)

def status_for(token):
    try:
        payload = signing.loads(token, salt=SALT, max_age=MAX_AGE)
        session = DrivingSession.objects.select_related("user", "device").get(
            pk=payload["session"], user_id=payload["user"], device_run_id=payload["run"])
        if not session.user.is_active or not hmac.compare_digest(payload["auth"], password_stamp(session.user)):
            raise ValueError("Revoked")
    except (signing.BadSignature, DrivingSession.DoesNotExist, KeyError, ValueError, TypeError):
        raise AuthenticationFailed("Phone alarm authorisation expired or was revoked. Reopen Monitor.")
    inactive = {"monitoring": False, "run_id": str(session.device_run_id), "sound_enabled": False}
    if session.end_time or not session.device.is_active or session.device.user_id != session.user_id:
        return inactive
    profile, _ = UserProfile.objects.get_or_create(user=session.user)
    if not profile.detection_enabled:
        return inactive
    request_started = time.monotonic()
    state = monitoring.device_request("GET", "/api/status").json()
    transit = time.monotonic() - request_started
    if str(state.get("run_id")) != str(session.device_run_id) or not state.get("monitoring"):
        return inactive
    try:
        sample_age = float(state.get("sample_age_seconds")) + transit
        if not math.isfinite(sample_age) or not 0 <= sample_age <= 5:
            raise ValueError("Stale sample")
    except (ValueError, TypeError, OverflowError):
        raise monitoring.DeviceUnavailable("No fresh detection sample. Check the Pi camera and update its device code.")
    event = state.get("last_alarm_event") or {}
    try:
        age = float(state.get("alarm_event_age_seconds")) + transit
        fresh = math.isfinite(age) and 0 <= age <= 10 and event.get("event_type") in {"microsleep", "long_closure"}
    except (ValueError, TypeError, OverflowError):
        fresh = False
    return {"monitoring": True, "run_id": str(session.device_run_id),
        "sound_enabled": profile.alert_sound_enabled,
        "microsleep_active": state.get("microsleep_active") is True,
        "alarm_event_id": str(event.get("id", "")) if fresh else "",
        "calibrating": state.get("calibrating") is True,
        "driver_detected": state.get("driver_detected") is True}
