from django.contrib import admin
from .models import UserProfile, Device, DrivingSession, DrowsinessEvent

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "full_name", "vehicle_model", "updated_at"]
    search_fields = ["user__username", "full_name"]

@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ["name", "device_id", "user", "is_active"]
    list_filter = ["is_active"]

@admin.register(DrivingSession)
class DrivingSessionAdmin(admin.ModelAdmin):
    list_display = ["id", "user", "device", "start_time", "end_time"]
    readonly_fields = ["device_run_id"]

@admin.register(DrowsinessEvent)
class DrowsinessEventAdmin(admin.ModelAdmin):
    list_display = ["event_type", "session", "timestamp", "duration"]
    list_filter = ["event_type"]
    readonly_fields = ["source_id"]

