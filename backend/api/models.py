from django.db import models
from django.utils import timezone
from django.contrib.auth.models import User


class UserProfile(models.Model):
    push_notifications_enabled = models.BooleanField(default=False)
    vehicle_model = models.CharField(max_length=100, blank=True)
    detection_enabled = models.BooleanField(default=True)
    alert_sound_enabled = models.BooleanField(default=True)
    sensitivity = models.CharField(max_length=10, choices=[("Low", "Low"), ("Medium", "Medium"), ("High", "High")], default="Medium")

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="profile"
    )

    full_name = models.CharField(
        max_length=150,
        blank=True
    )

    phone_number = models.CharField(
        max_length=30,
        blank=True
    )

    profile_picture = models.ImageField(
        upload_to="profile_pictures/",
        null=True,
        blank=True
    )

    # =========================
    # Emergency Contact
    # =========================

    emergency_contact_name = models.CharField(
        max_length=150,
        blank=True
    )

    emergency_contact_phone = models.CharField(
        max_length=30,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f"{self.user.username} Profile"


class Device(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="devices"
    )

    name = models.CharField(
        max_length=100
    )

    device_id = models.CharField(
        max_length=100,
        unique=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    is_active = models.BooleanField(
        default=True
    )

    def __str__(self):
        return self.name


class DrivingSession(models.Model):
    device_run_id = models.UUIDField(null=True, blank=True, unique=True)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="driving_sessions"
    )

    device = models.ForeignKey(
        Device,
        on_delete=models.CASCADE,
        related_name="sessions"
    )

    start_time = models.DateTimeField()

    end_time = models.DateTimeField(
        null=True,
        blank=True
    )

    vehicle_moving = models.BooleanField(
        default=False
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return f"Session {self.id} - {self.user.username}"


class DrowsinessEvent(models.Model):
    source_id = models.UUIDField(null=True, blank=True, unique=True)

    EVENT_TYPES = [
        ("drowsiness", "Drowsiness"),
        ("microsleep", "Microsleep"),
        ("long_closure", "Long Eye Closure"),
    ]

    session = models.ForeignKey(
        DrivingSession,
        on_delete=models.CASCADE,
        related_name="events"
    )

    event_type = models.CharField(
        max_length=30,
        choices=EVENT_TYPES
    )

    timestamp = models.DateTimeField()

    duration = models.FloatField(
        null=True,
        blank=True
    )

    ear_value = models.FloatField(
        null=True,
        blank=True
    )

    confidence = models.FloatField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return f"{self.event_type} - Session {self.session.id}"
class PushRegistration(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="push_registrations")
    token = models.CharField(max_length=512, unique=True)
    active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)


class PushDelivery(models.Model):
    event = models.ForeignKey(DrowsinessEvent, on_delete=models.CASCADE, related_name="push_deliveries")
    registration = models.ForeignKey(PushRegistration, on_delete=models.CASCADE, related_name="deliveries")
    status = models.CharField(max_length=12, default="pending")
    attempts = models.PositiveIntegerField(default=0)
    next_attempt = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    message_id = models.CharField(max_length=300, blank=True)
    last_error = models.CharField(max_length=100, blank=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["event", "registration"], name="unique_event_push_registration")]
        indexes = [models.Index(fields=["status", "next_attempt"], name="push_ready_index")]
