# DriveAlert Flutter app

Read the root README for setup of the backend, Pi and paired device key.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000/api
```

The login screen's **Server connection** button can change the backend address for the current app session. The app connects to Django for monitoring status, start/stop and frames; it does not require a separate Pi address.

Register the Pi serial matching the backend configuration in Settings before starting monitoring.

Journey reports are under Analytics. History displays saved records. GPS rest-stop search opens Maps with the phone's actual location.

Firebase push notifications are not configured in this build. Password reset email delivery depends on backend SMTP settings.

Use the root VALIDATION.md for automated results and target-device checks.

