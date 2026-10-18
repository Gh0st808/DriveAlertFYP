from django.http import HttpResponse
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from . import monitoring


class MonitorStatusView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        return Response(with_phone_alarm(request.user, monitoring.status(request.user)))


class MonitorStartView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request):
        return Response(with_phone_alarm(request.user, monitoring.start(request.user)))


def with_phone_alarm(user, state):
    from .models import DrivingSession
    from .phone_alarm import token_for
    if state.get("monitoring") and state.get("run_id"):
        session = DrivingSession.objects.select_related("user").filter(
            user=user, end_time__isnull=True, device_run_id=state["run_id"]).first()
        if session:
            state["phone_alarm_token"] = token_for(session)
    return state


class PhoneAlarmStatusView(APIView):
    # The capability only reads one journey's minimal alarm state; it is not a JWT.
    permission_classes = [AllowAny]
    authentication_classes = []
    def get(self, request):
        from .phone_alarm import status_for
        from rest_framework.exceptions import AuthenticationFailed
        header = request.headers.get("Authorization", "")
        if not header.startswith("Monitor "):
            raise AuthenticationFailed("Phone alarm authorisation required.")
        return Response(status_for(header[8:]), headers={"Cache-Control": "no-store"})


class MonitorStopView(APIView):
    permission_classes = [IsAuthenticated]
    def post(self, request):
        return Response(monitoring.stop(request.user))


class MonitorFrameView(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        monitoring.registered_device(request.user)
        response = monitoring.device_request("GET", "/api/frame", timeout=2)
        return HttpResponse(response.content, content_type="image/jpeg", headers={"Cache-Control": "no-store"})

