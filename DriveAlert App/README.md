# DriveAlert mobile app

Flutter interface for monitoring, journeys, reports and account settings.

## Run

From this directory:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000/api
```

The app connects to Django, which coordinates the Pi. Register the device serial in Settings before starting monitoring.

## Check

```powershell
flutter analyze
flutter test
```

Rebuild and install after native Android changes. Configure Firebase and the selected AI provider on the backend; actual delivery and target-phone audio require device checks.

- [Project setup](../docs/SETUP.md)
- [Screens and workflows](../docs/features/MOBILE_APP.md)
- [Android alerts](../docs/deployment/PHONE_ALARMS.md)
- [Testing](../docs/testing/VALIDATION.md)
