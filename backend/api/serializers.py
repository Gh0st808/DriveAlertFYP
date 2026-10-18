import math
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from rest_framework import serializers
from .models import UserProfile, Device, DrivingSession, DrowsinessEvent


class UserProfileSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(write_only=True, required=False)
    class Meta:
        model = UserProfile
        fields = ["full_name", "phone_number", "vehicle_model",
                  "emergency_contact_name", "emergency_contact_phone",
                  "profile_picture", "detection_enabled", "alert_sound_enabled",
                  "sensitivity", "push_notifications_enabled", "created_at", "updated_at", "email"]
        read_only_fields = ["created_at", "updated_at"]

    def validate_profile_picture(self, image):
        if image and image.size > 5 * 1024 * 1024:
            raise serializers.ValidationError("Choose an image smaller than 5 MB.")
        return image

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exclude(pk=self.instance.user_id).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    @transaction.atomic
    def update(self, instance, validated_data):
        email = validated_data.pop("email", None)
        if email is not None:
            instance.user.email = email
            instance.user.save(update_fields=["email"])
        return super().update(instance, validated_data)


class UserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    profile = UserProfileSerializer(read_only=True)
    full_name = serializers.CharField(write_only=True, required=False, max_length=150)
    vehicle_model = serializers.CharField(write_only=True, required=False, max_length=100)
    email = serializers.EmailField(required=True)

    class Meta:
        model = User
        fields = ["id", "username", "email", "password", "profile", "full_name", "vehicle_model"]
        read_only_fields = ["id"]

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    def validate(self, attrs):
        try:
            validate_password(attrs["password"], User(username=attrs["username"], email=attrs["email"]))
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": error.messages})
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        full_name = validated_data.pop("full_name", "")
        vehicle_model = validated_data.pop("vehicle_model", "")
        user = User.objects.create_user(**validated_data)
        UserProfile.objects.create(user=user, full_name=full_name, vehicle_model=vehicle_model)
        return user


class UserAccountUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["username", "email"]

    def validate_email(self, value):
        value = value.strip().lower()
        if not value:
            raise serializers.ValidationError("Email is required.")
        if User.objects.filter(email__iexact=value).exclude(pk=self.instance.pk).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value


class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = ["id", "user", "name", "device_id", "created_at", "is_active"]
        read_only_fields = ["id", "user", "created_at"]


class DrivingSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DrivingSession
        fields = ["id", "user", "device", "start_time", "end_time", "vehicle_moving", "created_at", "device_run_id"]
        read_only_fields = ["id", "user", "created_at", "device_run_id"]

    def validate(self, attrs):
        device = attrs.get("device", getattr(self.instance, "device", None))
        if device and (device.user_id != self.context["request"].user.pk or not device.is_active):
            raise serializers.ValidationError({"device": "Choose your active registered device."})
        start = attrs.get("start_time", getattr(self.instance, "start_time", None))
        end = attrs.get("end_time", getattr(self.instance, "end_time", None))
        if end and start and end < start:
            raise serializers.ValidationError({"end_time": "End time must be after start time."})
        if self.instance and self.instance.device_run_id:
            raise serializers.ValidationError("Use monitoring controls for a device-managed session.")
        return attrs


class DrowsinessEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = DrowsinessEvent
        fields = ["id", "session", "event_type", "timestamp", "duration", "ear_value", "confidence", "created_at", "source_id"]
        read_only_fields = ["id", "created_at", "source_id"]

    def validate(self, attrs):
        session = attrs.get("session", getattr(self.instance, "session", None))
        if session and session.user_id != self.context["request"].user.pk:
            raise serializers.ValidationError({"session": "Choose your own session."})
        for field in ("duration", "ear_value", "confidence"):
            value = attrs.get(field)
            if value is not None and (not math.isfinite(value) or value < 0):
                raise serializers.ValidationError({field: "Enter a finite non-negative number."})
        if attrs.get("confidence") is not None and attrs["confidence"] > 1:
            raise serializers.ValidationError({"confidence": "Confidence must be between 0 and 1."})
        return attrs

