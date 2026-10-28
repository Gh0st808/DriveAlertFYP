# Mobile application

[← Documentation](../README.md)

## Screens

| Area | Workflow |
| --- | --- |
| Account | Registration, login, password reset and profile management |
| Dashboard | Account summary, device status and navigation |
| Monitor | Start/stop, calibration, camera preview and current detection state |
| History | Saved sessions and detection records |
| Analytics | Period summaries and journey reports |
| Assistant | Chat with the configured backend provider and optional account summary |
| Rest Stops | Nearby categories, recommendations and directions |
| SOS | Hold-to-activate interaction, contact dialler and message composer |
| Settings | Device registration, notification and detection preferences |

## Connection

Supply the backend address at launch using the root `run_app.ps1` helper or the `API_BASE_URL` Dart define. The app accesses the Pi through Django; it does not require a separate device URL. Server addresses are not part of the normal driver interface.

## Monitoring

Register the device serial associated with the backend configuration. Start monitoring, keep the face visible and eyes open during calibration, and stop at the end of the trial. Review History and Analytics against the saved session.

The interface handles connection changes and failed frame requests. This does not guarantee uninterrupted operation during every camera, operating-system or network failure.

## Build and check

Run from the app directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000/api
```

Native changes require a complete rebuild and installation. Hot reload does not install Android service, manifest, resource or audio changes.

## Device checks

Check layouts on the target phone, profile persistence, actual GPS results, notification permissions, foreground/background audio and recovery after disconnection. Use a stationary setup and do not place emergency calls during testing.

See [validation](../testing/VALIDATION.md), [phone alerts](../deployment/PHONE_ALARMS.md) and [rest stops](REST_STOPS.md).
