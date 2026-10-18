import hmac
from datetime import datetime, timedelta, timezone as dt_timezone
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import serializers
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import PushRegistration, UserProfile, DrivingSession, DrowsinessEvent
from . import push

class RegistrationSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=512, min_length=20, trim_whitespace=True)

class EventInput(serializers.Serializer):
    id = serializers.UUIDField()
    event_type = serializers.ChoiceField(choices=["microsleep", "drowsiness", "long_closure"])
    timestamp = serializers.FloatField()
    duration = serializers.FloatField(min_value=0, max_value=86400)
    ear_value = serializers.FloatField(min_value=0, max_value=2)

    def validate_timestamp(self, value):
        import math
        if not math.isfinite(value):
            raise serializers.ValidationError("Invalid timestamp.")
        try:
            stamp = datetime.fromtimestamp(value, dt_timezone.utc)
        except (ValueError, OSError, OverflowError):
            raise serializers.ValidationError("Invalid timestamp.")
        if stamp > timezone.now() + timedelta(minutes=5):
            raise serializers.ValidationError("The Pi clock is ahead. Synchronise its clock.")
        return stamp

    def validate(self, data):
        import math
        if any(not math.isfinite(data[key]) for key in ("duration", "ear_value")):
            raise serializers.ValidationError("Values must be finite.")
        return data

class PushRegistrationView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = RegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        registration, _ = PushRegistration.objects.update_or_create(
            token=serializer.validated_data["token"], defaults={"user": request.user, "active": True})
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile.push_notifications_enabled = True
        profile.save(update_fields=["push_notifications_enabled"])
        return Response({"registered": True, "server_configured": push.configured()})

    def delete(self, request):
        serializer = RegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        PushRegistration.objects.filter(user=request.user, token=serializer.validated_data["token"]).delete()
        return Response(status=204)

class DeviceEventView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    @transaction.atomic
    def post(self, request):
        expected = settings.DEVICE_API_KEY
        if not expected or not hmac.compare_digest(request.headers.get("X-Device-Key", ""), expected):
            return Response({"detail": "Invalid device key."}, status=403)
        try:
            import uuid
            run_id = uuid.UUID(str(request.data.get("run_id", "")))
        except (ValueError, TypeError):
            return Response({"detail": "A valid run_id is required."}, status=400)
        session = DrivingSession.objects.select_related("device", "user").filter(
            device_run_id=run_id, device__device_id=settings.DEVICE_SERIAL_NUMBER).first()
        if session is None:
            return Response({"detail": "Run has not been registered with this backend."}, status=404)
        serializer = EventInput(data=request.data.get("event", {}))
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        event, created = DrowsinessEvent.objects.get_or_create(source_id=data["id"], defaults={
            "session": session, "event_type": data["event_type"], "timestamp": data["timestamp"],
            "duration": data["duration"], "ear_value": data["ear_value"]})
        if event.session_id != session.pk:
            return Response({"detail": "Event identity belongs to another run."}, status=409)
        transaction.on_commit(lambda: push.enqueue(event))
        return Response({"saved": True, "created": created}, status=201 if created else 200)

class PushStatusView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        return Response({
            "enabled": profile.push_notifications_enabled,
            "server_configured": push.configured(),
            "registered_devices": PushRegistration.objects.filter(user=request.user, active=True).count(),
        })

class PushTestView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request):
        from types import SimpleNamespace
        serializer = RegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        registration = PushRegistration.objects.filter(user=request.user, active=True,
            token=serializer.validated_data["token"]).first()
        if registration is None:
            return Response({"detail": "Enable notifications on this phone first."}, status=400)
        if not UserProfile.objects.filter(user=request.user, push_notifications_enabled=True).exists():
            return Response({"detail": "Push notifications are disabled."}, status=400)
        if not push.configured():
            return Response({"detail": "Firebase server credentials are not configured."}, status=503)
        try:
            push.send_notification(registration, SimpleNamespace(pk="test", session_id="test"), test=True)
        except Exception as error:
            return Response({"detail": "Firebase could not send the test. Check the backend Firebase setup.",
                             "error_type": type(error).__name__}, status=503)
        return Response({"detail": "Test notification accepted by Firebase. Check your phone."})

