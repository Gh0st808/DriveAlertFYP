[← Documentation](../README.md)

# Firebase notifications and Gemini Assistant

The source is integrated. Actual cloud delivery, a native Android build and live Gemini replies still require the checks below. Do not put private service-account JSON or Gemini keys in the Flutter app, Git or distributed files.

## 1. Configure the backend

For a new installation, run `python configure.py` first to configure the database and pair the Pi key. For an existing installation, keep its database credentials and matching device key; add the new cloud settings rather than replacing its .env. The backend accepts both DB_* variables and the original MYSQL_* database variables.

From the project root:

```powershell
python configure_firebase.py
```

Enter the absolute path of the **Firebase Admin service-account JSON**, outside the project. The helper validates its project ID and saves only its path in backend/.env. This project expects `drivealert-36c76`. Private credentials and .env files are excluded from version control. Configure the credential path separately for each installation. The backend account must be able to read that file. A backend running on the Pi needs a securely installed credential and the Pi's own absolute path; a Windows path will not work there.

Install backend requirements and apply migrations, preserving your database:

```powershell
.\setup_backend.ps1
```

This installs firebase-admin and applies additive migration 0005. Do not fake or delete migrations to bypass an error. Then run these in separate terminals:

```powershell
.\start_backend.ps1
```

```powershell
.\start_notifications.ps1
```

Run one notification worker. Firebase status showing configuration as "Present" confirms settings exist, not successful delivery. The explicit phone test below verifies delivery.

## 2. Update the Pi

Deploy the updated device folder while preserving events.sqlite3. In its .env, set BACKEND_URL to the Django API address reachable from the Pi, for example `http://192.168.4.1:8000/api`. DEVICE_API_KEY must match the backend. Restart the device service.

The Pi now keeps a metadata delivery outbox and retries uploads independently of the app. Django associates each upload with the registered run and queues fresh microsleep/long-closure warnings for opted-in phones. Basic drowsiness is retained in history without push. Events older than five minutes are synchronised but not pushed. Queue retries are best effort; a worker crash around delivery can repeat a notification. Android uses a common notification tag to reduce stacking. Do not use cloud push as a substitute for the local Android phone alarm described in ../deployment/PHONE_ALARMS.md.

## 3. Install and test Android

The public Firebase config is already embedded in lib/firebase_options.dart and android/app/src/main/res/values/firebase_config.xml. The values match `drivealert-36c76` and Android package `com.example.drivealert`. Resources are defined manually instead of adding the Google Services Gradle plugin; do not add both approaches. No private credential belongs in Android. iOS/APNs and web push are not configured.

From DriveAlert App, with an internet connection:

```powershell
flutter pub get
flutter analyze
dart tool/verify_api.dart
flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000/api
```

Run flutter pub get before building. Full Dart analysis and Android source compilation have passed, but these checks do not establish a complete native build or device-runtime result. Install the rebuilt APK on an Android phone with Google Play services. Keep both backend and phone connected to the internet for cloud features; keep the local phone/backend/Pi connection available for monitoring. See ../deployment/PHONE_ALARMS.md for background audio setup.

1. Sign in and open Settings -> Notification Preferences -> Enable on this phone.
2. Grant Android notification permission. Denial is reported; enable permission in Android system settings before retrying.
3. Choose Send test to this phone. A success response means FCM accepted the request; confirm the notification actually appears. Test foreground, background and a normally closed app. Android force-stop can prevent delivery until reopened.
4. Start a stationary monitoring trial and create a controlled microsleep/long-closure event. Check history and notification delivery with the worker running.
5. Turn notifications off, repeat and confirm no new cloud notification. Existing already-delivered notifications can remain in the tray. Test logout/account switching too.
6. If the test fails, check the backend's generic error class, service-account project/permissions, internet access, FCM API availability, Play services, phone permission and worker process. Never post private JSON contents or registration tokens in diagnostics.

## 4. Activate Gemini

Create a Gemini API key in [Google AI Studio](https://aistudio.google.com/api-keys). The Firebase Admin JSON is a different credential and does not supply a Gemini API key.

From the project root:

```powershell
python configure_gemini.py
```

Paste the key into the hidden local prompt. It writes only backend/.env; restart Django afterward. GEMINI_MODEL defaults to `gemini-2.5-flash` and can be changed in the backend environment to a compatible text model available to your project. Quota, project access and provider availability still apply.

Open Dashboard -> AI Assistant while parked. Ask an app-help question and confirm a real response. Enable the optional seven-day summary and confirm its counts match saved account records. Test missing key, provider/quota failure and conversation clear. The app reports failures rather than fabricating an AI answer.

The proxy requires login, limits requests to 10 per minute per account, bounds messages/history/output and keeps the key on the server. Chat text is sent to Google Gemini. Optional summaries include only the current account's saved last-seven-day journey/warning counts; there are no automatic video, photo, location or contact uploads. Unsynchronised Pi events are not included. Conversation context is held in the screen's memory and cleared on leaving; this app does not persist chat transcripts, but provider data policies still apply. Turning the summary switch off stops attaching a new summary; clear the conversation if you also want earlier assistant references removed from context.

## References

- https://firebase.google.com/docs/android/google-services-plugin-and-file
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://firebase.google.com/docs/admin/setup
- https://firebase.google.com/docs/cloud-messaging/send/admin-sdk
- https://ai.google.dev/api/generate-content
- https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash
