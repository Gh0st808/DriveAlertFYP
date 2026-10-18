# Phone microsleep alarms

The Android phone is the audible alert output. The Pi performs detection and reports numeric state. PI_AUDIO_ENABLED defaults to false; a Pi speaker is not required.

## Behaviour

- Start Monitoring checks Android notification permission, nonzero alarm volume and battery-optimization exemption, starts the Pi run through Django, then starts a visible Android foreground service.
- The service polls a minimal, authenticated journey-status endpoint approximately once per second. It continues independently of Flutter screen timers when another screen is open, the app is backgrounded or the phone is locked.
- A current microsleep closure sounds the bundled alert continuously. A fresh microsleep/long-closure event also produces a five-second pulse, so a short event between polls is not lost. The same event does not restart its pulse repeatedly. Basic drowsiness, ordinary blinks and calibration do not trigger this alarm.
- Stop Monitoring stops the phone service after the backend confirms the stop. Logging out also stops the phone service. The Alert Sound account preference is read live; disabling Firebase push does not disable the local alarm.
- A persistent notification shows active monitoring, calibration, muted sound, zero volume or a lost connection. Camera samples older than five seconds and delayed network responses are rejected, rather than replayed as live detections.
- The service uses a read-only capability scoped to one account and journey. It cannot retrieve account details, control the Pi or use other JWT endpoints. Password changes, journey completion and device reassignment invalidate its access. The capability expires after 24 hours without renewal; reopen Monitor to renew it. It is stored only in Android private preferences, with Android app backup disabled. Firebase/Gemini keys are never included.

## Install and use

This change includes native Android code and permissions. **Stop Flutter and perform a full rebuild/install; hot reload is insufficient.** Use the existing run_app.ps1 command with the working backend URL. For the current USB setup, keep adb reverse tcp:8000 tcp:8000 and use http://127.0.0.1:8000/api. Android forwards that connection to Django on the laptop; Django connects to the Pi.

1. Allow Android notifications for DriveAlert and its live-monitoring channel.
2. Open Background alarm settings in Monitor and allow DriveAlert unrestricted battery use / remove it from battery optimization. The app checks this before arming background alarms because Doze otherwise restricts polling and wake locks. Then raise the phone's **alarm volume**, not just its media volume. Check that Do Not Disturb permits alarms. The app does not change system volume or override Do Not Disturb.
3. Open Monitor and choose Test phone alarm before starting. This plays the bundled sound for up to five seconds without creating a fake detection.
4. Start Monitoring while the app is visible. Keep your face visible and eyes open for calibration. Confirm the persistent phone-monitoring notification appears.
5. Under controlled, stationary conditions, create a microsleep warning. Verify sound with Monitor visible, another app open, and the phone locked.
6. Verify a blink and basic drowsiness do not trigger the microsleep alarm. Verify prolonged closure continues sounding, recovery ends it after any minimum pulse, and a separate later closure can sound again.
7. Turn Alert Sound off/on in Settings and verify it affects local audio. Stop monitoring and confirm the service notification disappears and sound stops.
8. Disconnect/reconnect the monitoring connection. Confirm the notification reports loss and no stale alarm loops. Keep the session running on the Pi for this check, then reconnect and stop normally.

On Samsung, also verify DriveAlert is not in Sleeping apps or Deep sleeping apps. The app requires Android battery-optimization exemption before starting; vendor-specific restrictions still need target-phone testing. Test on the actual target phone: Android force-stop, reboot, the user's active-app Stop control, revoked permissions and vendor battery policies can stop services. The implementation does not claim an alarm survives those actions. Monitoring must be started again after a force-stop/reboot. It does not start automatically at phone boot.

## Connectivity and limits

The local alarm does **not** require Firebase, Gemini or internet, but it requires a working **phone -> backend -> Pi** connection and the backend process. With the current USB workaround, the cable and forwarding must remain available. The standalone Wi-Fi connection remains a separate pending task. Losing that connection means no new detection information can reach the phone; detection and event journalling can continue on the Pi, but there is no default Pi speaker fallback.

Wake/Wi-Fi locks are limited to the active service and released when it stops. They increase battery usage. Polling and network delivery add delay after the Pi detection threshold; measure the actual delay on your hardware. Real locked-screen audio and a full APK for this revision remain hardware/build acceptance checks, not inferred from logic tests.

Web and iOS do not implement this Android background alarm service.

## Primary references

- https://developer.android.com/develop/background-work/services/fgs/service-types
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/media/optimize/audio-focus
- https://developer.android.com/develop/background-work/background-tasks/awake

- https://developer.android.com/training/monitoring-device-state/doze-standby
