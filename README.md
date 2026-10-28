# DriveAlert

**Real-time eye-closure monitoring with Raspberry Pi and a Flutter mobile app.**

DriveAlert combines camera-based Eye Aspect Ratio (EAR) detection, a Django REST API and a mobile interface for monitoring journeys, reviewing events and viewing reports.

[Getting started](docs/SETUP.md) · [Architecture](docs/ARCHITECTURE.md) · [Testing](docs/testing/VALIDATION.md) · [Accuracy evaluation](testing/accuracy/README.md)

## System

| Component | Technology | Responsibility |
| --- | --- | --- |
| Mobile application | Flutter / Dart | Monitoring controls, preview, history, analytics and settings |
| Backend | Django REST Framework / MySQL | Accounts, devices, sessions, event records and reporting |
| Edge device | Raspberry Pi / Python / Flask / MediaPipe | Camera capture, calibration, EAR detection and local event storage |
| Evaluation | Python / scikit-learn / Matplotlib | Labelled-trial metrics and confusion-matrix figures |

The mobile app communicates with Django. Django coordinates the Raspberry Pi and synchronises detection records.

## Features

- Live camera preview, calibration and monitoring status.
- Blink, drowsiness, microsleep and long-closure event handling.
- Journey management, detection history, analytics and reports.
- Account profiles, registered devices and access controls.
- Local event storage and synchronisation following interrupted communication.
- Android alerts, push notifications and AI assistant integration.

## Getting started

1. Configure the backend address, device address and database using `python configure.py`.
2. Start the backend with `setup_backend.ps1` and `start_backend.ps1`.
3. On the Pi, run `setup_pi.sh` and start `device.py` inside the device virtual environment.
4. Launch the app with the backend URL:

```powershell
.\run_app.ps1 -BackendUrl "http://YOUR_BACKEND_IP:8000/api"
```

See the [setup guide](docs/SETUP.md) for prerequisites, network configuration and complete commands.

## Project structure

| Directory | Contents |
| --- | --- |
| [DriveAlert App/](DriveAlert%20App/) | Flutter application and interface tests |
| [DriveAlert Device/](DriveAlert%20Device/) | Camera service, detection logic, journal and device tests |
| [backend/](backend/) | Django API, database models, migrations and backend tests |
| [testing/accuracy/](testing/accuracy/) | Trial template, evaluation script and result figures |
| [docs/](docs/README.md) | Setup, deployment, configuration and testing documentation |

## Documentation

| Guide | Purpose |
| --- | --- |
| [Setup](docs/SETUP.md) | Configure and run the complete system |
| [Architecture](docs/ARCHITECTURE.md) | Components, detection and data flow |
| [Raspberry Pi deployment](docs/deployment/RASPBERRY_PI.md) | Install and operate the device service |
| [Phone alerts](docs/deployment/PHONE_ALARMS.md) | Android permissions, audio and background behaviour |
| [Cloud services](docs/configuration/CLOUD.md) | Firebase notifications and Gemini configuration |
| [ILMU assistant](docs/configuration/ILMU.md) | Configure the ILMU provider |
| [Mobile application](docs/features/MOBILE_APP.md) | Screens and mobile workflows |
| [Rest stops](docs/features/REST_STOPS.md) | Location search, filters and directions |
| [Testing](docs/testing/VALIDATION.md) | Test commands, recorded results and acceptance checks |
| [Accuracy evaluation](testing/accuracy/README.md) | Ground-truth labels, confusion matrix and metrics |
| [Changelog](docs/CHANGELOG.md) | Development changes |

## Evaluation and data

Use a stationary setup for intentional eye-closure trials. Prolonged closure is a simulated detection condition, not medical confirmation of microsleep. Report measured accuracy only after collecting labelled observations.

Camera frames are processed in memory; journey metadata and detection records are retained. Keep credentials and `.env` files private. See the deployment guides for operating requirements and limitations.
