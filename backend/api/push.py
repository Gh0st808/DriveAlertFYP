"""Durable notification queue. Never use push delivery as the Pi's local alarm."""
from datetime import timedelta
import logging
import threading
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from .models import PushRegistration, PushDelivery, UserProfile

logger = logging.getLogger(__name__)
_init_lock = threading.Lock()

def configured():
    return bool(settings.FIREBASE_ENABLED and settings.GOOGLE_APPLICATION_CREDENTIALS)

def enqueue(event):
    if not configured() or event.event_type not in {"microsleep", "long_closure"}:
        return
    age = timezone.now() - event.timestamp
    if age < timedelta(seconds=-60) or age > timedelta(minutes=5):
        return
    if not UserProfile.objects.filter(user=event.session.user, push_notifications_enabled=True).exists():
        return
    for registration in PushRegistration.objects.filter(user=event.session.user, active=True):
        PushDelivery.objects.get_or_create(event=event, registration=registration)

def send_notification(registration, event, dry_run=False, test=False):
    import firebase_admin
    from firebase_admin import credentials, messaging
    with _init_lock:
        try:
            app = firebase_admin.get_app("drivealert-push")
        except ValueError:
            app = firebase_admin.initialize_app(
                credentials.Certificate(settings.GOOGLE_APPLICATION_CREDENTIALS),
                {"projectId": settings.FIREBASE_PROJECT_ID, "httpTimeout": 15}, name="drivealert-push")
    message = messaging.Message(
        token=registration.token,
        notification=messaging.Notification(
            title="DriveAlert test notification" if test else "DriveAlert: fatigue event recorded",
            body="Your phone can receive DriveAlert notifications." if test else "A prolonged eye closure was recorded. Review your journey when safely stopped."),
        data={"event_id": str(event.pk), "session_id": str(event.session_id), "route": "/history"},
        android=messaging.AndroidConfig(
            priority="high", ttl=timedelta(minutes=5),
            notification=messaging.AndroidNotification(tag="drivealert-fatigue", sound="default", channel_id="drivealert_alerts_v2")),
    )
    return messaging.send(message, dry_run=dry_run, app=app)

def process_one():
    now = timezone.now()
    # One worker per deployment is sufficient; the lease also recovers interrupted jobs.
    with transaction.atomic():
        job = (PushDelivery.objects.select_for_update()
               .filter(status__in=["pending", "sending"], next_attempt__lte=now)
               .order_by("created_at").first())
        if job is None:
            return False
        registration = job.registration
        event = job.event
        if (not registration.active or registration.user_id != event.session.user_id
                or not UserProfile.objects.filter(user_id=registration.user_id, push_notifications_enabled=True).exists()
                or now - event.timestamp > timedelta(minutes=5)):
            job.status = "cancelled"
            job.save(update_fields=["status"])
            return True
        job.status = "sending"
        job.attempts += 1
        job.next_attempt = now + timedelta(seconds=45)
        job.save(update_fields=["status", "attempts", "next_attempt"])
    try:
        message_id = send_notification(registration, event)
    except Exception as error:
        # Error classes only: never persist SDK messages that may include credentials or tokens.
        code = type(error).__name__
        if code in {"UnregisteredError", "SenderIdMismatchError"}:
            PushRegistration.objects.filter(pk=registration.pk).update(active=False)
        job.status = "failed" if job.attempts >= 5 or code in {"UnregisteredError", "SenderIdMismatchError"} else "pending"
        job.last_error = code
        job.next_attempt = timezone.now() + timedelta(seconds=min(120, 5 * 2 ** job.attempts))
        job.save(update_fields=["status", "last_error", "next_attempt"])
        logger.warning("Push delivery %s failed (%s)", job.pk, code)
    else:
        job.status = "sent"
        job.message_id = message_id
        job.sent_at = timezone.now()
        job.last_error = ""
        job.save(update_fields=["status", "message_id", "sent_at", "last_error"])
    return True

