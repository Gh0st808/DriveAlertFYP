[← Project overview](../README.md)

# DriveAlert setup and operation

This package repairs the complete project copied from your existing **DriveAlert FYP** folder. The uploaded ZIP was an older Flutter UI-only version. The original folder and your MySQL database were not modified.

## Start here

For the **18 October repair**, applying it without replacing private configuration, and checks that still need the laptop/phone/Pi, read **[REPAIR_NOTES_2026-10-18.md](../REPAIR_NOTES_2026-10-18.md)** first. Earlier validation documents describe earlier revisions.

For the latest visual changes, verified checks and remaining physical-device tests, see **[APP_REVIEW.md](../APP_REVIEW.md)**. The app UI is updated in this working copy; rebuild/install it with run_app.ps1 to see the changes on the phone.

Use a new extracted folder for this version. Keep your current project and back up your existing MySQL database before applying migrations. This package preserves migrations 0001–0003 and adds 0004; it does not reset accounts or erase tables.

The connection is now **phone → Django backend → Pi**. The phone needs only the backend address. The backend must be able to reach the Pi.

Choose the configuration matching your setup:

| Setup | Phone backend address | Backend DEVICE_URL |
| --- | --- | --- |
| Backend on laptop, Pi on same home Wi-Fi | http://LAPTOP_WIFI_IP:8000/api | http://PI_WIFI_IP:5000 |
| Backend and device service both on Pi hotspot | http://192.168.4.1:8000/api | http://127.0.0.1:5000 |

If your phone joins the Pi hotspot while Django stays on a disconnected laptop network, it cannot reach Django. Put the laptop on a reachable network or run Django on the Pi.

## 1. Configure both services

From the extracted project root:

```powershell
python configure.py
```

The script asks for the backend IP, Pi IP and MySQL credentials. It creates paired backend/device configuration with random secrets. For your current MySQL installation, use your existing database name, user and password. It does not create or delete a database.

Copy **DriveAlert Device including its newly created .env** to the Pi. Keep .env files private. Do not mix keys from different configuration runs.

On a changed Wi-Fi network, update backend/.env:

- DJANGO_ALLOWED_HOSTS: add the backend's current reachable Wi-Fi IP.
- DEVICE_URL: the Pi address reachable from Django.
- Rebuild the app using run_app.ps1 -BackendUrl http://CURRENT_LAPTOP_IP:8000/api.

Server addresses are kept out of the driver interface. The run script supplies API_BASE_URL at build time.

## 2. Start the backend on Windows

From the project root:

```powershell
.\setup_backend.ps1
.\start_backend.ps1
```

The setup script creates a new backend virtual environment, installs requirements, checks Django and runs migrations. MySQL must already be running and the database must exist. Allow Python inbound access on your trusted private network if Windows Firewall blocks the phone.

If migrations fail, keep the complete error. **Do not delete migration files, drop tables or use --fake to bypass it.** An existing database with a different migration history needs inspection first.

If PowerShell blocks scripts, you can run the equivalent commands manually:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

## 3. Start the device on the Pi

Use 64-bit Raspberry Pi OS and a connected camera. The phone provides audible alerts. The device uses Picamera2 for the Pi camera and MediaPipe Tasks for landmarks.

Inside the copied device folder:

```bash
bash setup_pi.sh
.venv/bin/python device.py
```

The setup script installs camera packages, creates a virtual environment with access to system camera libraries, installs Python dependencies and downloads the face landmark model once. Internet is required for installation and model download. Existing face_landmarker.task files are kept.

For a USB webcam instead of the Pi CSI camera, set CAMERA_BACKEND=opencv and CAMERA_INDEX=0 in the device .env. The default is picamera2.

Local preview is off so the service can run without a desktop. Set SHOW_PREVIEW=true only when a graphical desktop is available. Camera frames are held in memory, sent on authenticated requests and never saved.

After confirming manual startup, optional boot startup:

```bash
bash install_service.sh
journalctl -u drivealert-device -f
```

This installs the **device API** at boot. Monitoring starts when you press Start in the app. The script does not install the Django backend as a boot service or change your hotspot.

## 4. Run the Flutter app

Use the existing Flutter SDK (Dart 3.12.2 or newer):

```powershell
.\run_app.ps1 -BackendUrl "http://YOUR_BACKEND_IP:8000/api"
```

Or:

```powershell
cd "DriveAlert App"
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000/api
```

For a web demo, use port 8080 so it matches the default CORS setting:

```powershell
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000/api
```

1. Register an account or log in with an existing username/email.
2. Open Settings and register the physical Pi serial **DRIVEALERT-PI-001**, matching backend DEVICE_SERIAL_NUMBER. If it already belongs to your existing account, use that account.
3. Open Monitor and press Start.
4. Keep your eyes open and face visible until calibration completes.
5. Stop monitoring. Review History and Analytics → Journey reports.
6. Start again or leave/return to Monitor: session identity is maintained by the backend and Pi, rather than the screen's memory.

Do not delete an active device. Stop its journey first.

## Password reset and notifications

Password reset now generates a real, expiring, single-use link with a browser reset form. The default **console email backend prints the link in Django's terminal**. It does not deliver email to an inbox.

To send actual email, set EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend and complete the EMAIL_HOST, EMAIL_PORT, EMAIL_HOST_USER, EMAIL_HOST_PASSWORD, EMAIL_USE_TLS and DEFAULT_FROM_EMAIL settings in backend/.env. The reset link must use an address reachable by its recipient.

Android Firebase push and a backend Gemini chatbot are integrated. See [CLOUD_SETUP.md](../CLOUD_SETUP.md) for credential setup, dependency installation, the notification worker and live phone checks. Firebase public configuration matches drivealert-36c76 / com.example.drivealert. Private credentials and Gemini keys are excluded from this archive. The chatbot needs a Gemini key before live replies work. Phone alarm service is independent of push notifications; report suggestions remain based on recorded counts.

## Data flow and recovery

Each Pi run has a UUID. The Pi stores journey metadata and numeric detections in events.sqlite3. Django imports those records idempotently when status/history/reports are requested and when monitoring stops.

- Leaving Monitor does not stop Pi detection or the active Android phone-alarm service. The phone/backend/Pi connection must remain available; force-stop/reboot require rearming.
- Repeating Start during an uncertain response uses the pending run ID.
- Repeating Stop does not duplicate events.
- A backend outage leaves events on the Pi for later synchronisation.
- A Pi restart ends the interrupted run at its last saved heartbeat; the next backend request recovers that run.
- Device preferences are stored with your account. If a running Pi cannot be reached, open Monitor to check its actual state. Saved preferences are applied on the next start.
- Keep Pi and backend clocks synchronised for event history and cloud delivery. The live phone alarm uses monotonic sample/event ages, rather than trusting cross-device wall clocks.
- Keep events.sqlite3 when replacing device code. It contains unsynchronised history; it contains no video.

Event duration is elapsed eye-closure time **at threshold crossing**, rather than the final duration of the entire closure. A sustained closure may generate drowsiness, microsleep and long-closure warning types. Counts are once per type per closure; audio can repeat without increasing the event count.

## Detection thresholds

The original sensitivity ratios and detection times are retained:

| Sensitivity | Drowsy EAR ratio | Microsleep EAR ratio | Drowsy time | Microsleep time |
| --- | --- | --- | --- | --- |
| Low | 0.72 | 0.60 | 0.70 s | 1.00 s |
| Medium | 0.76 | 0.64 | 0.50 s | 0.80 s |
| High | 0.80 | 0.70 | 0.35 s | 0.60 s |

Calibration requires 50 valid open-eye samples, with EAR 0.20–0.50 and coefficient of variation ≤0.12. Long closures use 3 seconds. These are project thresholds; this repair does not establish detection accuracy, precision, recall or F1-score. Evaluate them with labelled controlled trials on your device.

## Backend on the Pi

The backend can also run on the Pi to keep the whole demo reachable through its hotspot. Install Python build dependencies and the chosen MySQL client development libraries, create a backend virtual environment, install backend/requirements.txt, configure .env and run migrations before starting Django on 0.0.0.0:8000.

MySQL remains the default. DB_ENGINE=sqlite is an explicit optional setting for a separate portable demo, and uses a new local database. It does not import or replace your existing MySQL records. The Windows setup scripts do not provision a database server on the Pi.

## Validation and limits

See [VALIDATION.md](../VALIDATION.md) for the actual automated results and checks still requiring your hardware. This is a local FYP development setup. Django runserver and HTTP LAN addresses are for local demonstrations; internet deployment still requires production hosting, HTTPS, restricted hosts/origins and production secrets.

Primary implementation references:

- https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/python
- https://pypi.org/project/mediapipe/1.1.1/
- https://datasheets.raspberrypi.com/camera/picamera2-manual.pdf


## Phone audio and Pi deployment update

The phone, rather than the Pi, is the default audible output. [PHONE_ALARMS.md](../PHONE_ALARMS.md) explains the Android foreground service, permission/volume/battery requirements, local connection dependency and locked-screen checks. [PI_DEPLOYMENT.md](../PI_DEPLOYMENT.md) contains the current Pi deployment steps. Rebuild and install the Android app fully; hot reload cannot install this native change. PI_AUDIO_ENABLED=false is the default.
