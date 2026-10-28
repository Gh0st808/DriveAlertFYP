# DriveAlert device service

Raspberry Pi camera acquisition, EAR detection, Flask API and local event storage.

## Run

Configure matching backend/device keys using the root setup guide. On the Pi, from this directory:

```bash
bash setup_pi.sh
.venv/bin/python device.py
```

The default camera backend is Picamera2, with headless operation on port 5000. Authenticated requests coordinate monitoring through Django.

## Service

After checking manual operation:

```bash
bash install_service.sh
journalctl -u drivealert-device -f
```

Preserve the environment file, landmark model and events.sqlite3 when updating. Frames are not stored in the event journal.

## Tests

```bash
.venv/bin/python -m unittest test_device -v
```

- [Deployment](../docs/deployment/RASPBERRY_PI.md)
- [Phone alerts](../docs/deployment/PHONE_ALARMS.md)
- [Validation](../docs/testing/VALIDATION.md)
