# Changelog

[← Documentation](README.md)

## 29 October 2026

- Added the Python detection-evaluation tool under testing/accuracy.
- Added an empty labelled-trial CSV and result figures for confusion matrices and metrics.
- Included per-lighting summaries, missing-prediction counts and prediction coverage.
- Organised documentation by setup, configuration, deployment, features and testing.

## 18 October 2026

- Foreground Firebase messages now also post Android notification-tray alerts through a dedicated high-importance channel. The backend and manifest select that same channel. Tapping a local alert opens History, including after login if needed.
- Phone test and monitoring alarms use a new repeating three-beep WAV. The Pi can use the same file when its optional audio is enabled. This is a replacement alert sound, not evidence of measured waking effectiveness.
- Poor-visibility warnings appear after approximately three seconds without usable face tracking and clear on recovery. The app and the background monitoring notification show the warning without turning it into a microsleep event or a wake-up alarm.
- Calibration discards prior samples after out-of-range readings or a detection gap. A gap longer than one second cannot be counted as continuously observed eye closure. Counters remain available during tracking loss.
- Picamera2 capture waits at most two seconds for a frame job. Preview encoding runs independently at approximately 3 Hz; app polling runs at 2 Hz, with one request in flight. Stale device frames are rejected. Failed app requests clear the old image, abort their transport, and retry. Old Flutter image-cache entries are evicted.
- A connection loss no longer disables Stop for a session known to be running. A physical/native camera or inference hang can still require restarting the Pi service; bounded capture is not a guarantee against every hardware failure.
- Rest Stops keeps category filters, recommendations and directions, removes the large header and distance selector, and puts a Maps search at the top. Nearby data still depends on location permission, internet and the public map service; unavailable data is not replaced with invented places.
- Added a native launcher icon with a driver, closed-eye mark and detection corners.
- Profile-upload authentication retries are tied to the initiating account, avoiding a retry under another account after a sign-out/sign-in race.

See [validation](testing/VALIDATION.md) for recorded checks and remaining device requirements.
