# DriveAlert device service

Read the project root README first to generate paired configuration.

Copy this entire directory, including your generated .env, onto the Pi. Keep the same DEVICE_API_KEY in the Django backend and Pi configurations.

```bash
bash setup_pi.sh
.venv/bin/python device.py
```

The service defaults to Picamera2, headless operation and port 5000. Start monitoring through the authenticated Flutter app; direct API requests require X-Device-Key.

For an optional local preview, set SHOW_PREVIEW=true while running on a desktop. For USB cameras use CAMERA_BACKEND=opencv.

To run the API at boot after manual verification:

```bash
bash install_service.sh
journalctl -u drivealert-device -f
```

Keep events.sqlite3 across code updates. It stores detection metadata for later backend synchronisation, with no camera images.

The Face Landmarker model must be present. setup_pi.sh invokes download_model.py if the model is missing. A model already on your Pi can be reused.

Tests:

```bash
.venv/bin/python -m unittest test_device -v
```

These tests verify logic and API behaviour without using the physical camera or speaker. Use the root VALIDATION.md checklist for hardware verification.


## Phone alerts

PI_AUDIO_ENABLED=false is the default. The Pi reports current microsleep state and fresh alarm-event ages; the Android foreground service plays the sound, even when its screen is locked, subject to the requirements in ../PHONE_ALARMS.md. Keep a working phone -> Django -> Pi connection. See ../PI_DEPLOYMENT.md for current transfer/configuration steps.
