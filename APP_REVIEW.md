# App polish and remaining checks

Updated 16 October 2026.

## Completed

- Shared blue/navy theme, rounded Material icons, cards, controls and navigation across the main destinations.
- Redesigned dashboard with account totals, device connection state, camera status, reports, history and rest-stop links.
- Assistant bubble on Home, Analytics and Settings opens a dismissible chat panel with suggestions, optional saved warning summaries and keyboard support. Monitor and SOS stay focused on driving.
- Removed the login server-address editor and visible backend address. Addresses remain internal connection settings.
- Removed EAR/FPS diagnostics, raw sync errors and technical setup instructions from driver screens. Permission, battery, volume, connection and form-validation guidance remain visible.
- Fixed narrow-screen overflow on Dashboard, chat, Analytics, Monitor and Sign Up.
- Prevented delayed camera frames from reappearing after monitoring stops or its control state changes.
- Fixed follow-up chat validation for long assistant responses.
- Removed the Kotlin compiler-options block from the Java-only Android app module, which does not apply the Kotlin plugin.

## Verification

- Dart analysis of lib and test: no issues.
- 35 Flutter checks: transport/authentication, history, technical-message hiding, login, dashboard/chat at 320 and 412 logical pixels (including keyboard, sending and closing), twelve other screen layouts, and nine nearby-place service/screen checks. APIs and location are mocked.
- 51 backend tests pass against isolated SQLite test settings, including the long-chat-history regression. The real MySQL database is not modified by these tests.
- Dashboard and chat widget renders were inspected internally using real text/icon fonts. They are not physical-phone screenshots.
- A full Android APK build was blocked by this session's inability to write the Flutter SDK cache lock at C:\flutter. No new APK is supplied or installed by this session.

## Apply on the phone

Keep the backend and notification worker running. Stop the previous Flutter run with Ctrl+C. From the repaired project folder run:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_app.ps1 -Device R7AX309GLWH
```

This rebuilds using the current hotspot backend address. The launcher's BackendUrl option can select another network address; there is no address editor in the driver UI. Restart the backend once for the chat-history change. No new database migration is required. Existing local private configuration is retained and excluded from the distribution ZIP.

## Remaining physical checks or setup

1. **Camera/calibration:** check actual Pi video, complete calibration and verify eye reopening/face loss clear warnings. Measure accuracy using labelled trials; tests do not imply a detection accuracy percentage.
2. **Phone alarms:** check permission, battery exemption and alarm volume, then test actual warnings with the app visible, backgrounded and locked. Verify connection loss/recovery and stopping the same journey. Test only while parked.
3. **Push notifications:** verify the test notification and a new real warning arrive with the worker running. Configuration presence alone is not delivery verification.
4. **Saved data:** stop a real journey and compare History, Analytics and Journey reports. Save/reload profile/photo/vehicle/contact changes on the phone.
5. **Password-reset email:** configure SMTP and verify inbox delivery. Console email is a development workflow, not email delivery.
6. **Rest stops/Maps/contacts:** nearby recommendations now use OpenStreetMap with category filters, distance selection and individual directions. See REST_STOPS.md. Verify actual GPS/results and opening Maps on the target phone, plus permission-denied recovery, the dialler and message composer. Do not place test emergency calls.
7. **Laptop availability:** keep the laptop awake and backend running. Hotspot reconnects can change its IP. Automatic startup and stable address/discovery remain optional work, outside this UI revision.
8. **Release deployment:** public/store distribution still requires production serving, HTTPS, release signing and deployment configuration. The current setup is a local demonstration.

The user confirmed ILMU replies worked before this UI revision. No new provider key or hosting purchase is needed for these visual changes. API keys and database files are not packaged.
