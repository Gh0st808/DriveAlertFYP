from .push_views import PushRegistrationView, PushStatusView, DeviceEventView, PushTestView
from .chat_views import ChatView
from .auth_views import ResetRequestView, reset_confirm, ChangePasswordView
from .monitor_views import MonitorStatusView, MonitorStartView, MonitorStopView, MonitorFrameView, PhoneAlarmStatusView
from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    RegisterView,
    LoginView,
    RefreshTokenView,
    CurrentUserView,
    UserProfileView,
    UserAccountView,
    DeviceViewSet,
    DrivingSessionViewSet,
    DrowsinessEventViewSet,
    AnalyticsSummaryView,
)

router = DefaultRouter()

router.register(
    r"devices",
    DeviceViewSet,
    basename="device"
)

router.register(
    r"sessions",
    DrivingSessionViewSet,
    basename="session"
)

router.register(
    r"events",
    DrowsinessEventViewSet,
    basename="event"
)

urlpatterns = [
    path("monitor/phone-alarm/", PhoneAlarmStatusView.as_view()),
    path("chat/", ChatView.as_view()),
    path("notifications/registration/", PushRegistrationView.as_view()),
    path("notifications/status/", PushStatusView.as_view()),
    path("notifications/test/", PushTestView.as_view()),
    path("device/events/", DeviceEventView.as_view()),
    path("auth/password-reset/", ResetRequestView.as_view()),
    path("auth/password-reset/<str:uid>/<str:token>/", reset_confirm, name="password_reset_confirm"),
    path("auth/change-password/", ChangePasswordView.as_view()),
    path("monitor/api/status", MonitorStatusView.as_view()),
    path("monitor/api/monitor/start", MonitorStartView.as_view()),
    path("monitor/api/monitor/stop", MonitorStopView.as_view()),
    path("monitor/api/frame", MonitorFrameView.as_view()),
    path(
        "auth/register/",
        RegisterView.as_view(),
        name="register"
    ),

    path(
        "auth/login/",
        LoginView.as_view(),
        name="login"
    ),

    path(
        "auth/refresh/",
        RefreshTokenView.as_view(),
        name="token_refresh"
    ),

    path(
        "auth/me/",
        CurrentUserView.as_view(),
        name="current_user"
    ),

    path(
        "profile/",
        UserProfileView.as_view(),
        name="profile"
    ),

    path(
        "account/",
        UserAccountView.as_view(),
        name="account"
    ),

    path(
        "analytics/summary/",
        AnalyticsSummaryView.as_view(),
        name="analytics_summary"
    ),
]

urlpatterns += router.urls
