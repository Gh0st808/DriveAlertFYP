# DriveAlert

**Camera-based driver monitoring with a Raspberry Pi device and Flutter mobile app.**

DriveAlert uses facial landmarks and the Eye Aspect Ratio (EAR) to identify prolonged eye closure. A Django backend connects the mobile app to the device and stores journey and detection records for History, Analytics and reports.

[Setup guide](docs/SETUP.md) · [Accuracy evaluation](testing/accuracy/README.md) · [Pi deployment](PI_DEPLOYMENT.md) · [Validation](VALIDATION.md)

## Overview

| Component | Role | Technology |
| --- | --- | --- |
| Mobile app | Monitoring controls, live preview, history, analytics and settings | Flutter / Dart |
| Backend | Authentication, device access, sessions, records and reporting | Django REST Framework / MySQL |
| Edge device | Camera capture, calibration, EAR detection and local event storage | Raspberry Pi / Python / Flask / MediaPipe |
| Evaluation tool | Labelled-trial metrics and confusion-matrix figures | Python / scikit-learn / Matplotlib |

The phone communicates with Django, and Django communicates with the Pi. The phone needs the backend address; the backend needs a reachable device address.

## Features

- Live monitoring with calibration, camera preview and detection status.
- Blink, drowsiness, microsleep and long-closure event handling.
- Journey start/stop, event history, analytics and reporting.
- Account profiles, registered devices and access restrictions.
- Local event storage and synchronisation after interrupted communication.
- Android phone alerts, notification processing and an AI assistant backend.

Implementation checks and deployment limitations are documented in [VALIDATION.md](VALIDATION.md) and [APP_REVIEW.md](APP_REVIEW.md). Feature descriptions are not claims of measured detection accuracy.

## Getting started

Use a connected Pi camera, a reachable local network, an existing MySQL database and the required Python / Flutter environments.

| Step | Action | Guide |
| --- | --- | --- |
| 1 | Configure the backend and device addresses, paired keys and existing database credentials | [Configure services](docs/SETUP.md#1-configure-both-services) |
| 2 | Install backend dependencies and start Django | [Windows backend](docs/SETUP.md#2-start-the-backend-on-windows) |
| 3 | Install device dependencies and start the camera service | [Raspberry Pi device](docs/SETUP.md#3-start-the-device-on-the-pi) |
| 4 | Run the mobile app with the backend URL | [Flutter app](docs/SETUP.md#4-run-the-flutter-app) |

Run the Windows setup commands from the repository root:

```powershell
python configure.py
.\setup_backend.ps1
.\start_backend.ps1
```

In another terminal, after starting the Pi device:

```powershell
.\run_app.ps1 -BackendUrl "http://YOUR_BACKEND_IP:8000/api"
```

Keep your existing database and private configuration. The [full setup guide](docs/SETUP.md) includes manual commands, network options and migration guidance.

## Detection accuracy evaluation

The evaluation tool is in **[testing/accuracy/](testing/accuracy/)**. It reads recorded trial labels and DriveAlert predictions, then produces:

- Confusion-matrix and metric-summary images.
- Accuracy, precision, recall and F1-score for classified trials.
- Separate lighting summaries, prediction coverage and missing-prediction counts.
- CSV records and a JSON result record.

The [trial template](testing/accuracy/trials.csv) is intentionally empty. Real observations are required; no accuracy scores are prefilled.

[Read the evaluation instructions →](testing/accuracy/README.md)

## Repository layout

| Location | Contents |
| --- | --- |
| [DriveAlert App/](DriveAlert%20App/) | Flutter application |
| [DriveAlert Device/](DriveAlert%20Device/) | Camera service, detection logic and device tests |
| [backend/](backend/) | Django API, models, migrations and backend tests |
| [testing/accuracy/](testing/accuracy/) | Python detection-evaluation tool |
| [docs/SETUP.md](docs/SETUP.md) | Full configuration and operating instructions |
| Root scripts | Configuration helpers and startup commands |

## Documentation

| Topic | Guide |
| --- | --- |
| Configuration and operation | [Setup guide](docs/SETUP.md) |
| Pi deployment | [PI_DEPLOYMENT.md](PI_DEPLOYMENT.md) |
| Android alerts and background behaviour | [PHONE_ALARMS.md](PHONE_ALARMS.md) |
| Firebase and cloud services | [CLOUD_SETUP.md](CLOUD_SETUP.md) |
| ILMU assistant configuration | [ILMU_SETUP.md](ILMU_SETUP.md) |
| Nearby rest stops | [REST_STOPS.md](REST_STOPS.md) |
| Checks and known limitations | [VALIDATION.md](VALIDATION.md) |
| App review and revision notes | [APP_REVIEW.md](APP_REVIEW.md) |
| Repair history | [18 October notes](REPAIR_NOTES_2026-10-18.md) · [Earlier repairs](REPAIRS.md) |
| Repository import history | [REPOSITORY_IMPORT.md](REPOSITORY_IMPORT.md) |

## Evaluation scope and data

DriveAlert is an FYP prototype. Use a stationary setup for controlled eye-closure trials; intentional closure does not medically confirm microsleep. Camera frames are processed in memory rather than saved as permanent video, while journey metadata and detection records are retained.

Keep credentials and `.env` files private. Deployment requirements and remaining hardware checks are documented in the guides above.
