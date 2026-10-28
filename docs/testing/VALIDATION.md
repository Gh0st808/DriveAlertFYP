# Testing and validation

[← Documentation](../README.md)

## Run the checks

From the repository root:

```powershell
.\validate_update.ps1
```

Use `-BuildApk` to include a debug APK build. This requires a configured backend environment, Flutter and the Android toolchain.

### Backend

```powershell
cd backend
.\.venv\Scripts\python.exe manage.py test api --settings=config.test_settings
.\.venv\Scripts\python.exe manage.py makemigrations --check --dry-run --settings=config.test_settings
```

The test settings select isolated SQLite storage. Install the device dependencies in the test environment to include the Flask protocol tests; otherwise those tests are skipped. Tests must not be presented as completed when their dependencies cause skips.

### Device

On the Pi, from the device directory:

```bash
.venv/bin/python -m unittest test_device -v
```

The logic/API tests use controlled inputs and temporary storage, not the physical camera.

### Flutter

```powershell
cd "DriveAlert App"
flutter pub get
flutter analyze
dart tool/verify_api.dart
flutter test
```

Mocked service and location tests do not establish live provider or GPS operation.

## Recorded software checks

Counts apply to the corresponding recorded source snapshot. They are not cumulative and do not assert that this documentation change reran the tests.

| Snapshot | Check | Recorded outcome | Scope |
| --- | --- | --- | --- |
| 16 October 2026 | Django backend | 51 passed | Account, ownership, synchronisation, notifications, assistant and alarm status; isolated SQLite |
| 16 October 2026 | Device logic/API | 12 passed | Detection, persistence, access and delivery behaviour |
| 16 October 2026 | Dart transport | 8 passed | Mocked transport and authentication scenarios |
| 16 October 2026 | Flutter widget/transport | 35 passed | Interface and service tests with mocked dependencies |
| 16 October 2026 | Django checks and migration consistency | Passed | Models and migrations |
| 16 October 2026 | Flutter analysis | No issues recorded | Analysed source revision |
| 18 October 2026 | Django backend | 53 passed | In-memory SQLite |
| 18 October 2026 | Device logic/API | 18 passed | No physical camera |
| 18 October 2026 | Native alarm policy | 10 assertions passed | Decision logic |
| 18 October 2026 | Java source compilation | Passed with bridge/resource stubs | Not a full APK or actual Flutter embedding check |
| 18 October 2026 | Python compilation, Dart/Java parsing and XML checks | Completed | Syntax/structure checks |
| 18 October 2026 | Added Flutter regressions | Not run in that snapshot | Failed-frame, Stop and Rest Stop controls |

A complete Android package, target-phone behaviour and live cloud delivery are separate checks. iOS background alarms are not implemented. Password-reset testing through a local outbox does not confirm SMTP delivery.

## Recorded device observations

| Case | Outcome | Observation |
| --- | --- | --- |
| Phone/backend/Pi connection | Passed | Components connected |
| Monitoring start | Passed | Camera and session checks passed |
| Calibration | Passed | Calibration completed |
| Preview and status | Passed with observation | Some lag |
| Brief blinks | Passed | Expected blink behaviour |
| Intentional prolonged closure | Passed | Event, audible alert and recording checks passed |
| Face loss | Passed | Expected face-loss handling |
| Poor lighting | Failed | Detection did not work |
| Monitoring stop | Passed | Stop and session-persistence checks passed |
| History and Analytics | Passed | Stored-record comparison passed |
| Disconnect/reconnect | Passed | Synchronisation and duplicate checks passed |
| Background/locked-phone alarm | Pending | Physical check not completed |
| Device restart | Passed | Recovery check passed |

These observations have no recorded build identifier or quantitative latency/illuminance measurements. Retain original evidence and repeat checks for a new deployed build.

## Physical acceptance

- Confirm mutual network reachability and the registered device owner.
- Verify camera acquisition, open-eye calibration and preview freshness.
- Test brief blinks, intentional prolonged closure, face loss and visibility recovery while stationary.
- Check foreground, background and locked-screen phone alerts, permissions, alarm volume and battery settings.
- Compare completed journeys and event counts with History, Analytics and database records.
- Disconnect/reconnect and restart the service; confirm recovery without duplicates.
- Check profile persistence, GPS/Maps, contact dialler and message composer.
- Verify SMTP inbox delivery and cloud notifications separately.
- Keep the laptop awake while it hosts Django and the notification worker.

## Detection accuracy

Use the [Python evaluation tool](../../testing/accuracy/README.md) with independently labelled trial observations. Report confusion-matrix counts, accuracy, precision, recall, F1-score, prediction coverage and missing predictions. Separate lighting conditions.

Functional test passes are not an accuracy measurement. Intentional closure is a simulated condition, not medical confirmation of microsleep. No evaluation scores are prefilled.

## Deployment limits

The local HTTP/runserver configuration supports a controlled demonstration. Internet deployment requires production serving, HTTPS, appropriate origins/hosts and production secrets. Actual audio depends on phone permissions, settings and connectivity; logic checks do not guarantee audibility in all operating states.
