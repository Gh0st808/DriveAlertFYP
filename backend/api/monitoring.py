"""Coordinate the authenticated account, registered Pi and durable detection journal."""
import uuid
from datetime import datetime, timezone as dt_timezone
import json
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import APIException, PermissionDenied, ValidationError
from .models import Device, DrivingSession, DrowsinessEvent, UserProfile


class DeviceUnavailable(APIException):
    status_code = 503
    default_detail = "Cannot reach the DriveAlert device. Check its power, Wi-Fi and DEVICE_URL."


def device_request(method, path, data=None):
    try:
        request = Request(settings.DEVICE_URL.rstrip("/") + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={"X-Device-Key": settings.DEVICE_API_KEY, "Content-Type": "application/json"}, method=method)
        with urlopen(request, timeout=12) as response:
            content = response.read()
        class Result:
            def json(self):
                try:
                    return json.loads(content)
                except (ValueError, UnicodeDecodeError) as error:
                    raise DeviceUnavailable("The device returned an invalid response.") from error
        result = Result()
        result.content = content
        return result
    except HTTPError as error:
        try:
            detail = json.loads(error.read()).get("message", "Device request failed.")
        except (ValueError, OSError):
            detail = "Device request failed."
        if error.code == 409:
            raise ValidationError(detail)
        raise DeviceUnavailable(detail) from error
    except (URLError, OSError, ValueError) as error:
        raise DeviceUnavailable() from error


def registered_device(user, lock=False):
    query = Device.objects.select_for_update() if lock else Device.objects
    device = query.filter(device_id=settings.DEVICE_SERIAL_NUMBER, is_active=True).first()
    if not device or device.user_id != user.pk:
        raise PermissionDenied("Register the configured Pi serial number to this account in Settings first.")
    return device


def sync_session(session):
    if not session.device_run_id:
        return
    snapshot = device_request("GET", "/api/runs/" + str(session.device_run_id)).json()
    if snapshot.get("run_id") != str(session.device_run_id):
        raise DeviceUnavailable("Device run identity did not match.")
    with transaction.atomic():
        for event in snapshot.get("events", []):
            event_record, _ = DrowsinessEvent.objects.get_or_create(
                source_id=event["id"], defaults={
                    "session": session, "event_type": event["event_type"],
                    "timestamp": datetime.fromtimestamp(event["timestamp"], dt_timezone.utc),
                    "duration": event["duration"], "ear_value": event["ear_value"]})
            from .push import enqueue
            transaction.on_commit(lambda record=event_record: enqueue(record))
        if snapshot.get("ended_at") is not None:
            session.end_time = datetime.fromtimestamp(snapshot["ended_at"], dt_timezone.utc)
            if session.end_time < session.start_time:
                session.end_time = session.start_time
            session.save(update_fields=["end_time"])


def sync_user(user):
    error = None
    for session in DrivingSession.objects.filter(user=user, end_time__isnull=True, device_run_id__isnull=False):
        try:
            sync_session(session)
        except APIException as exception:
            error = str(exception.detail)
    return error


def status(user):
    registered_device(user)
    state = device_request("GET", "/api/status").json()
    error = sync_user(user)
    state["sync_error"] = error
    active = DrivingSession.objects.filter(user=user, end_time__isnull=True, device_run_id__isnull=False).first()
    state["session_id"] = active.pk if active else None
    return state


def start(user):
    sync_user(user)
    with transaction.atomic():
        device = registered_device(user, lock=True)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        if not profile.detection_enabled:
            raise ValidationError("Enable microsleep detection in Settings first.")
        session = DrivingSession.objects.filter(device=device, end_time__isnull=True, device_run_id__isnull=False).first()
        if session is None:
            session = DrivingSession.objects.create(
                user=user, device=device, start_time=timezone.now(), device_run_id=uuid.uuid4())
    # Keep this pending session on uncertain transport failures. A retry uses the same run ID.
    try:
        response = device_request("POST", "/api/monitor/start", {
            "run_id": str(session.device_run_id), "sensitivity": profile.sensitivity,
            "alert_sound_enabled": profile.alert_sound_enabled}).json()
    except APIException:
        sync_user(user)
        raise
    if not response.get("success"):
        raise DeviceUnavailable(response.get("message", "Device could not start."))
    return status(user)


def stop(user):
    with transaction.atomic():
        device = registered_device(user, lock=True)
        session = DrivingSession.objects.filter(device=device, end_time__isnull=True, device_run_id__isnull=False).first()
        if session is None:
            return {"success": True, "message": "No active session.", "monitoring": False}
        device_request("POST", "/api/monitor/stop", {"run_id": str(session.device_run_id)})
        sync_session(session)
        return {"success": True, "monitoring": False, "session_id": session.pk,
                "message": "Monitoring stopped and records saved."}

