# DriveAlert repair — 18 October 2026

This revision starts from the uploaded `DriveAlert-Repaired-main.zip`. It repairs the gaps confirmed in that snapshot; it does not recover unseen laptop files or the earlier generated icon artwork.

## Changes

- Foreground Firebase messages now also post Android notification-tray alerts through a dedicated high-importance channel. The backend and manifest select that same channel. Tapping a local alert opens History, including after login if needed.
- Phone test and monitoring alarms use a new repeating three-beep WAV. The Pi can use the same file when its optional audio is enabled. This is a replacement alert sound, not evidence of measured waking effectiveness.
- Poor-visibility warnings appear after approximately three seconds without usable face tracking and clear on recovery. The app and the background monitoring notification show the warning without turning it into a microsleep event or a wake-up alarm.
- Calibration discards prior samples after out-of-range readings or a detection gap. A gap longer than one second cannot be counted as continuously observed eye closure. Counters remain available during tracking loss.
- Picamera2 capture waits at most two seconds for a frame job. Preview encoding runs independently at approximately 3 Hz; app polling runs at 2 Hz, with one request in flight. Stale device frames are rejected. Failed app requests clear the old image, abort their transport, and retry. Old Flutter image-cache entries are evicted.
- A connection loss no longer disables Stop for a session known to be running. A physical/native camera or inference hang can still require restarting the Pi service; bounded capture is not a guarantee against every hardware failure.
- Rest Stops keeps category filters, recommendations and directions, removes the large header and distance selector, and puts a Maps search at the top. Nearby data still depends on location permission, internet and the public map service; unavailable data is not replaced with invented places.
- A temporary native vector icon shows a driver, closed-eye mark and detection corners, with the name DriveAlert. This is a new simple replacement, not the missing earlier illustration.
- Profile-upload authentication retries are tied to the initiating account, avoiding a retry under another account after a sign-out/sign-in race.

## Verification in this environment

- Django: **53 tests passed**, using an isolated in-memory SQLite test database. The real MySQL database was not accessed or changed.
- Device logic/API: **18 tests passed** without camera hardware.
- Native alarm policy: **10 assertions passed**.
- Android Java sources compile against Android 35 framework classes using temporary Flutter-bridge/resource stubs. This catches Java/API errors; it is **not an APK build** and does not verify the real Flutter embedding.
- Dart and Java syntax parsing, Python compilation, Android XML parsing and database migration consistency checked.
- Added Flutter regression tests for failed-frame recovery, Stop availability after disconnection, preview-request cancellation and the simplified Rest Stop controls. **These tests have not been run here.**
- Flutter analysis, widget tests, full Android build/install, live ILMU/FCM delivery and live map loading remain unverified here because Flutter and the target devices are unavailable. Run the supplied `validate_update.ps1` on the laptop.

## Apply on the laptop

1. Stop Flutter, the Django development server and the notification worker. Keep a backup of the working project.
2. Copy this revision's source into your existing repaired project. Keep the current `backend/.env`, private Firebase Admin credentials and virtual environments. The ZIP intentionally excludes those files. Do not run `configure.py` over a working configuration: it generates new pairing keys.
3. Keep the existing `drivealert_db`. No models or migrations were changed by this revision.
4. Run from the repaired project root:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\validate_update.ps1 -BuildApk
   ```

5. Start the backend and notification worker using their existing scripts. Fully rebuild/install the app; hot restart alone will not apply Android code, sound, icon or manifest changes:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\run_app.ps1 -Device R7AX309GLWH
   ```

   If the laptop IP changed, supply `-BackendUrl http://CURRENT_LAPTOP_IP:8000/api` and update the matching allowed host in your existing backend configuration.

## Apply on the Pi

Stop monitoring and stop `drivealert-device.service` before replacing device code. Copy the updated contents of `DriveAlert Device` into the directory used by that service. Preserve `.env`, `.venv`, `face_landmarker.task`, `events.sqlite3` and any related database journal files. Include the new `wake_alert.wav`. Do not copy a blank journal over an existing one.

Then run:

```bash
sudo systemctl restart drivealert-device.service
systemctl is-active drivealert-device.service
journalctl -u drivealert-device.service -n 40 --no-pager
```

## Physical acceptance still required

While parked, verify calibration with eyes naturally open, normal blinks, prolonged eye closure, face loss for at least three seconds and recovery. Check preview/Stop over several minutes, disconnect/reconnect, the test notification with the app open/backgrounded, and the phone alarm with the screen locked. Test the alarm somewhere appropriate, with the phone alarm volume audible.

Keep the laptop awake and reachable, the notification worker running, and the phone/Pi network connected. Preserve the currently working ILMU API key and model ID from your local `.env`; no key or live model access is included in this package. Password-reset inbox delivery still requires your SMTP configuration.
