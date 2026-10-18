# Repair record

Source: complete local DriveAlert FYP project, with permission from the user. The uploaded drivealert.zip was an older Flutter interface project with no service implementation.

## Repaired or completed

- Real backend registration saves full name and vehicle model; Django password validation is enforced.
- Login accepts either username or a uniquely matching email.
- Shared API transport refreshes expired JWTs once across concurrent requests, retries authenticated requests and bounds network waits.
- Password recovery uses Django's signed expiring reset tokens and an actual browser form. A working SMTP account is still needed for inbox delivery.
- Profile name, email, phone, photo and vehicle update through a validated multipart request; photo selection/upload also works without dart:io on web.
- Vehicle model no longer overwrites the registered device's name.
- A device's is_active flag is no longer displayed as if it meant monitoring was running.
- Backend/Pi coordinated monitoring uses stable run IDs, with idempotent retry and persistent event storage.
- Camera status, event-count and duration fields agree across all three components.
- Pi camera/landmark imports happen when monitoring starts; failure is reported through the API rather than crashing the whole service at import.
- Calibration no longer has the undeclared global-variable crash.
- Pi camera defaults to Picamera2; a USB/OpenCV alternative is configurable.
- MediaPipe Tasks replaces the cvzone legacy FaceMesh dependency.
- Headless operation is the default; local GUI display is optional.
- Audio initialisation failure is reported to the app and does not prevent the API from starting.
- Sustained eye closures generate one event of each warning type, while local audio can repeat.
- Loss of a valid face resets closure timers so separated periods are not combined.
- Pi metadata/event journal survives app closure and device-service restarts. Frames are never journalled.
- The app authenticates to Django; Django uses a paired secret for Pi API requests.
- Monitor frame/status polls do not overlap with themselves.
- Hardcoded dashboard Connected/Active/Awake indicators use actual service state.
- Detection history uses account-scoped backend records instead of examples.
- Today/Week/Month selections filter real summaries and event lists.
- Journey reports show start/end, driving duration, warnings, microsleep frequency and count-based rest suggestions; reports can be copied.
- Rest-stop search uses live phone coordinates and Maps instead of fabricated locations, distances and ratings.
- SOS uses a cancellable three-second hold timer, contact dialling and explicit location sharing.
- Android location/dialler declarations and iOS usage descriptions are provided.
- Detection/sound/sensitivity preferences persist in the backend and are applied to device runs.
- Change password is connected; About and Privacy describe actual behaviour.
- Backend credentials, hosts, CORS and device address/key move to environment configuration.
- Session/device and event/session ownership is checked on updates as well as creates.
- Invalid numeric values and end-before-start sessions are rejected.
- Migration history is preserved, with an additive 0004 migration.
- Paired configuration and Windows/Pi startup/setup scripts are included.

## Deliberately visible limitations

- Android Firebase code and public project configuration are supplied. Live delivery still requires dependency installation, a local service credential, the notification worker and a phone test.
- Gemini chatbot code is supplied; its server API key and live provider test remain pending.
- GPS/Maps and SMTP email require their respective service/network access.
- Native Android/iOS builds and actual camera and locked-phone alarm performance must be checked on the target hardware.
- Physical camera placement, alert audibility and model accuracy cannot be established from source code tests.
- Prior incomplete sessions and prior database migration discrepancies are preserved; this package does not rewrite historical data.
- The service installer starts only the Pi device API at boot. Django autostart and Pi database provisioning remain deployment tasks if the backend is moved to the Pi.


## Firebase and Gemini integration

- Authenticated phone-token registration, opt-in preferences, logout cleanup and explicit test delivery.
- Pi event outbox uploads independently of the app; backend queues fresh microsleep/long-closure notifications with retries and stale-event cancellation.
- Migration 0005 adds notification preferences, registrations and the durable delivery queue.
- Dashboard AI Assistant uses an authenticated, throttled backend proxy. Messages and optional account-scoped seven-day numeric summaries are sent to Gemini; credentials stay on the server.
- Chat supports conversation context, clear, retryable errors, unavailable-provider handling and bounded input/output. No camera-control or emergency actions are delegated to AI.
- CLOUD_SETUP.md and hidden-input configuration helpers explain activation and live validation.

## Phone is the speaker

- Native Android foreground monitoring service, scoped read-only journey token, local bundled audio, wake/Wi-Fi locks and live sound preference.
- Required visible service notification, notification/alarm-volume/battery preflight and background settings shortcut.
- Current microsleep state and fresh event identity/monotonic ages supplied by the Pi. Calibration, blinks, basic drowsiness and stale observations do not trigger this alarm.
- Stop/logout cleanup, no Firebase dependency, and explicit loss-of-connection status. Pi audio is opt-in and off by default.
- Android hardware/runtime validation and deployment remain pending.
