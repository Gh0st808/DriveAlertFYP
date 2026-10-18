from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.core.exceptions import ValidationError as DjangoValidationError
from django.http import HttpResponse
from django.template import engines
from django.urls import reverse
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.views.decorators.csrf import csrf_protect
from rest_framework import serializers
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer


class LoginSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        identifier = attrs.get("username", "").strip()
        if "@" in identifier:
            candidates = list(User.objects.filter(email__iexact=identifier)[:2])
            if len(candidates) == 1:
                attrs["username"] = candidates[0].username
        return super().validate(attrs)


class ResetRequestView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [AnonRateThrottle]

    def post(self, request):
        email = serializers.EmailField().run_validation(request.data.get("email", ""))
        for user in User.objects.filter(email__iexact=email, is_active=True):
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            url = request.build_absolute_uri(reverse("password_reset_confirm", args=[uid, token]))
            send_mail("DriveAlert password reset", "Open this link to reset your password:\n" + url,
                      settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)
        return Response({"detail": "If this email is registered, password reset instructions have been sent."})


@csrf_protect
def reset_confirm(request, uid, token):
    try:
        user = User.objects.get(pk=force_str(urlsafe_base64_decode(uid)), is_active=True)
    except (User.DoesNotExist, ValueError, TypeError, OverflowError):
        user = None
    valid = user is not None and default_token_generator.check_token(user, token)
    message = ""
    if request.method == "POST" and valid:
        password = request.POST.get("password", "")
        try:
            if password != request.POST.get("confirm", ""):
                raise DjangoValidationError("Passwords do not match.")
            validate_password(password, user)
            user.set_password(password)
            user.save(update_fields=["password"])
            valid = False
            message = "Password updated. Return to DriveAlert and sign in."
        except DjangoValidationError as error:
            message = " ".join(error.messages)
    elif not valid:
        message = "This reset link is invalid or has expired. Request another link."
    template = engines["django"].from_string(
        '<!doctype html><html><head><meta name="viewport" content="width=device-width">'
        '<title>DriveAlert password reset</title></head><body><h1>DriveAlert</h1><p>{{ message }}</p>'
        '{% if valid %}<form method="post">{% csrf_token %}'
        '<label>New password <input type="password" name="password" required minlength="8"></label><br>'
        '<label>Confirm password <input type="password" name="confirm" required></label><br>'
        '<button>Reset password</button></form>{% endif %}</body></html>')
    return HttpResponse(template.render({"valid": valid, "message": message}, request))


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        if not user.check_password(request.data.get("current_password", "")):
            raise serializers.ValidationError({"current_password": "Current password is incorrect."})
        password = request.data.get("new_password", "")
        try:
            validate_password(password, user)
        except DjangoValidationError as error:
            raise serializers.ValidationError({"new_password": error.messages})
        user.set_password(password)
        user.save(update_fields=["password"])
        return Response({"detail": "Password changed. Sign in again."})

