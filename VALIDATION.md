# Validation results

Validated on 16 October 2026 using the isolated repair copy and isolated SQLite test databases. Original project source is preserved. The user subsequently applied migrations 0004 and 0005 to MySQL successfully.

| Check | Result | Scope |
| --- | --- | --- |
| Django backend tests | **51 passed** | Registration, email login, password validation/reset/change, profile/email updates, account isolation, session times, device protection, reporting, durable sync and monitoring protocol; plus notification, Gemini/ILMU chatbot and journey-scoped phone-alarm checks, including long assistant-history follow-up |
| Pi logic and API tests | **12 passed** | Calibration, eye closures, blink separation, face loss, EAR edge case, metadata persistence/restart recovery, API key and run identity checks, metadata outbox acknowledgement/retry |
| App API transport checks | **8 passed** | Single concurrent refresh, sign-out race protection, registration payload, in-memory multipart upload/retry, period/control endpoints and invalid-refresh handling, account-switch retry protection and chat/notification request payloads |
| Django system checks | **Passed** | Executed with backend tests |
| Migration consistency | **Passed: no changes detected** | Existing migrations plus additive 0004 and 0005 match the models |
| Python syntax compilation | **Passed** | Backend, device modules and configure.py |
| Flutter/Dart static analysis | **No issues found** | Full lib analysis passed after Firebase dependencies became available; the latest phone-service/UI edits are also checked. |
| Flutter release web build | **Pending for this revision** | Previous pre-Firebase web build succeeded; it does not validate the current phone-alarm revision. The background alarm implementation targets Android. |
| Flutter widget and transport test runtime | **35 passed** | Shared transport, history, technical-message hiding, login, dashboard/chat at two phone widths, twelve other screen layouts, plus nine nearby-place service/screen checks; APIs/location are mocked |
| Android APK / iOS native build | **Android build blocked by SDK-cache permissions** | Android Java source compilation previously passed. This UI revision's full APK build could not acquire C:\flutter\bin\cache\lockfile. Complete APK/resource linking and actual background/locked-screen checks remain pending. iOS background alarms are not implemented. |
| Live MySQL migration | **User-confirmed applied** | Supplied console output shows migrations 0004 and 0005 applied successfully. New phone-alarm capability needs no additional database migration. Automated tests still use isolated SQLite. |
| Real camera/model/phone alarm | **Not run** | Requires your Raspberry Pi |
| Actual SMTP delivery | **Not configured** | Default reset links are printed to the backend terminal |
| Firebase cloud / Gemini live replies | **Not yet verified** | Provider logic tests use mocks. Firebase and Gemini credentials are configured in the local repair copy but excluded from the ZIP. Live cloud checks remain pending. See CLOUD_SETUP.md. |

**77 automated checks passed (47 backend, 12 device, 8 Dart transport, 10 native alarm decisions).** The two backend/Pi protocol tests use the actual Django and Flask API routes with an in-process transport and simulated camera loop. They do not establish physical camera operation or network connectivity.

## Repeat automated checks

Backend:

```powershell
cd backend
python manage.py test api --settings=config.test_settings
python manage.py makemigrations --check --dry-run --settings=config.test_settings
```

Install Flask/device requirements in the test environment to run the optional protocol tests; otherwise they are skipped.

Device:

```bash
cd "DriveAlert Device"
.venv/bin/python -m unittest test_device -v
```

App:

```powershell
cd "DriveAlert App"
flutter pub get
flutter analyze
dart tool/verify_api.dart
flutter test
flutter build web --no-web-resources-cdn
```

The standalone checker uses mock HTTP responses and requires no phone, Pi or loopback test server. It exercises the same cases as api_service_test.dart.

## Hardware acceptance checklist

Use controlled, stationary trials.

1. Back up MySQL, configure both services, apply migrations without deleting or faking migration history.
2. Confirm the phone can reach Django and Django can reach the Pi's configured address.
3. Sign in using the existing device-owning account, or register the Pi serial to a new account.
4. Start monitoring. Confirm the camera actually opens, fresh frames arrive and calibration completes only with a visible open-eyed face.
5. Confirm blink, drowsiness and microsleep counters behave with your chosen thresholds. Confirm the phone alarm is audible, including with the app backgrounded and phone locked; follow PHONE_ALARMS.md.
6. Leave Monitor, return and stop. Confirm one journey ends and History/Analytics show the same saved records.
7. Background the app and lock the phone during monitoring. Confirm a new warning sounds on the phone, then reopen and stop the same journey. Force-stop and reboot are outside the phone alarm's continuity guarantees.
8. Disconnect the backend temporarily, record events on the Pi and reconnect. Confirm events sync once, without duplicates.
9. Restart the device service after an interrupted journey and confirm the previous run closes at its saved heartbeat.
10. Edit profile name/email/phone/vehicle/photo and reload. Confirm the values persist, and that device registration remains separate.
11. Test password reset with the console link, then with your SMTP settings if inbox delivery is needed.
12. Grant/deny GPS permission and check the rest-stop search. Test contact dialler and message composer opening using a non-emergency contact; do not place emergency calls during testing.
13. Install the native Android build on the target phone and verify local-network access, permissions and background/resume behaviour.
14. Measure accuracy, precision, recall, F1-score, alert delay and false positives using labelled trials; no accuracy figures are inferred from unit tests.

The default HTTP, cleartext Android allowance, iOS transport allowance and Django runserver configuration support a local demonstration. Review these settings before an internet deployment.


## Cloud integration checks

The earlier 38 backend tests included 12 push tests and 7 Gemini proxy tests; the phone-alarm revision adds nine tests for a total of 47. They cover ownership, opt-out, idempotency, retry/error redaction, stale cancellation, authenticated Pi uploads, no fake test detections, chat validation/rate limits, provider failures, optional-summary isolation and credential redaction. The eight standalone Dart checks exercise the shared transport without Firebase initialization. These are logic tests, not proof of FCM/Gemini connectivity.

Run flutter pub get before analysis/build. No APK built from the latest native phone-alarm revision or updated web build is supplied. Follow CLOUD_SETUP.md and PHONE_ALARMS.md for real phone/provider acceptance checks.

## Phone-alarm integration revision

Nine additional backend tests verify the read-only journey capability, ownership, sound preferences, stale camera/event rejection, password/expiry revocation, stop semantics and device reassignment. Two device tests verify the live microsleep-active flag, eye reopening, face loss and calibration. Ten native Java decision checks cover pulses, event deduplication, sustained closure, mute and re-enable behaviour. Java sources compile against the installed Android 36 platform and Flutter embedding using temporary resource-ID stubs; this is a native source check, not a packaged APK or device runtime test. Full lib analysis and eight transport checks pass. The previous APK predates this native change and must be rebuilt.

Physical deployment and camera calibration, background/locked audio, Doze/battery settings, connectivity-loss and recovery remain required acceptance checks. Backend/Pi pairing has been prepared locally for Pi 10.13.1.217 and laptop 10.13.1.97; private configuration is excluded from the ZIP. See PHONE_ALARMS.md and PI_DEPLOYMENT.md.
