from datetime import timedelta
from django.utils import timezone
from django.db.models import Q
from rest_framework.throttling import AnonRateThrottle
from .auth_views import LoginSerializer
from . import monitoring
from django.contrib.auth.models import User

from rest_framework import generics, viewsets
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

from .models import (
    UserProfile,
    Device,
    DrivingSession,
    DrowsinessEvent,
)

from .serializers import (
    UserSerializer,
    UserProfileSerializer,
    UserAccountUpdateSerializer,
    DeviceSerializer,
    DrivingSessionSerializer,
    DrowsinessEventSerializer,
)


class RegisterView(generics.CreateAPIView):
    throttle_classes = [AnonRateThrottle]
    authentication_classes = []
    serializer_class = UserSerializer
    permission_classes = [AllowAny]


class LoginView(TokenObtainPairView):
    serializer_class = LoginSerializer
    throttle_classes = [AnonRateThrottle]
    authentication_classes = []
    permission_classes = [AllowAny]


class RefreshTokenView(TokenRefreshView):
    authentication_classes = []
    permission_classes = [AllowAny]


class CurrentUserView(generics.RetrieveAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        UserProfile.objects.get_or_create(user=self.request.user)
        return self.request.user


class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        profile, created = UserProfile.objects.get_or_create(
            user=self.request.user
        )

        return profile


    def perform_update(self, serializer):
        device_preferences = {"detection_enabled", "alert_sound_enabled", "sensitivity"}.intersection(serializer.validated_data)
        profile = serializer.save()
        if not device_preferences:
            return
        try:
            device = monitoring.registered_device(self.request.user)
            active = DrivingSession.objects.filter(device=device, end_time__isnull=True, device_run_id__isnull=False).exists()
            if active:
                if not profile.detection_enabled:
                    monitoring.stop(self.request.user)
                else:
                    monitoring.device_request("PATCH", "/api/settings", {
                        "sensitivity": profile.sensitivity, "alert_sound_enabled": profile.alert_sound_enabled})
        except monitoring.APIException:
            # Saved preferences are used on next start; no false device-state claim.
            pass


class UserAccountView(generics.UpdateAPIView):
    serializer_class = UserAccountUpdateSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

    def update(self, request, *args, **kwargs):
        user = self.get_object()

        serializer = self.get_serializer(
            user,
            data=request.data,
            partial=True
        )

        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            UserSerializer(
                user,
                context={"request": request}
            ).data
        )


class DeviceViewSet(viewsets.ModelViewSet):
    serializer_class = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Device.objects.filter(
            user=self.request.user
        )

    def perform_create(self, serializer):
        serializer.save(
            user=self.request.user
        )

    def perform_destroy(self, instance):
        from rest_framework.exceptions import ValidationError
        if instance.sessions.filter(end_time__isnull=True).exists():
            raise ValidationError("Stop monitoring and close active sessions before deleting the device.")
        instance.delete()

    def perform_update(self, serializer):
        from rest_framework.exceptions import ValidationError
        if serializer.instance.sessions.filter(end_time__isnull=True).exists():
            raise ValidationError("Stop monitoring before changing this device.")
        serializer.save()


class DrivingSessionViewSet(viewsets.ModelViewSet):
    serializer_class = DrivingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        monitoring.sync_user(self.request.user)
        return DrivingSession.objects.filter(user=self.request.user).order_by("-start_time")

    def perform_create(self, serializer):
        device = serializer.validated_data["device"]

        if device.user != self.request.user:
            from rest_framework.exceptions import PermissionDenied

            raise PermissionDenied(
                "You do not have permission to use this device."
            )

        serializer.save(
            user=self.request.user
        )


class DrowsinessEventViewSet(viewsets.ModelViewSet):
    serializer_class = DrowsinessEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        monitoring.sync_user(self.request.user)
        return DrowsinessEvent.objects.filter(session__user=self.request.user).order_by("-timestamp")

    def perform_create(self, serializer):
        session = serializer.validated_data["session"]

        if session.user != self.request.user:
            from rest_framework.exceptions import PermissionDenied

            raise PermissionDenied(
                "You do not have permission to use this session."
            )

        serializer.save()



class AnalyticsSummaryView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sync_error = monitoring.sync_user(request.user)
        now = timezone.now()
        period = request.query_params.get("period", "All")
        local_now = timezone.localtime(now)
        today = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
        since = {"Today": today, "Week": today - timedelta(days=local_now.weekday()),
                 "Month": today.replace(day=1)}.get(period)
        sessions = DrivingSession.objects.filter(user=request.user)
        events = DrowsinessEvent.objects.filter(session__user=request.user)
        if since:
            sessions = sessions.filter(Q(end_time__gte=since) | Q(end_time__isnull=True))
            events = events.filter(timestamp__gte=since)
        events = events.filter(timestamp__lte=now)
        durations = [max(0, (min(s.end_time or now, now) - max(s.start_time, since or s.start_time)).total_seconds()) for s in sessions]
        counts = {name: events.filter(event_type=name).count() for name in ("microsleep", "drowsiness", "long_closure")}
        total = sessions.count()
        advice = ("Stop driving at a safe place and rest before continuing." if counts["microsleep"] else
                  "Plan a rest break if you feel tired." if counts["drowsiness"] else
                  "Keep taking regular rest breaks and monitor for signs of fatigue.")
        return Response({
            "period": period, "total_sessions": total,
            "total_driving_duration_seconds": sum(durations),
            "total_microsleeps": counts["microsleep"], "total_drowsiness_events": counts["drowsiness"],
            "total_long_closures": counts["long_closure"],
            "average_microsleeps_per_session": counts["microsleep"] / total if total else 0,
            "recommendation": advice, "sync_error": sync_error,
        })
