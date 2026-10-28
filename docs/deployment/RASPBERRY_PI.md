# Raspberry Pi deployment

[← Documentation](../README.md)

The backend can run on the laptop while the Pi runs the camera service. Keep the phone, backend and device on mutually reachable networks.

## Pairing

Configure the installation from the repository root with `python configure.py`. This creates matching backend and device keys. Preserve existing working environment files when updating an installation.

| Setting | Location | Value |
| --- | --- | --- |
| DEVICE_URL | backend/.env | http://PI_IP:5000 |
| BACKEND_URL | Device .env | http://BACKEND_IP:8000/api |
| DEVICE_API_KEY | Both services | Matching private key |
| DEVICE_SERIAL_NUMBER | Backend | Serial registered to the signed-in account |

Set the app backend URL using `run_app.ps1 -BackendUrl http://BACKEND_IP:8000/api`. Rebuild after changing a compile-time URL.

## Transfer

On the Pi, enable SSH if required:

```bash
sudo systemctl enable --now ssh
```

From PowerShell in the local repository root, replace PI_IP with the Pi's address:

```powershell
scp -r "DriveAlert Device" "drivealert@PI_IP:/home/drivealert/"
```

The source folder must contain the paired device `.env`. Keep that file private. For an existing installation, use its actual service directory, stop monitoring and stop its device service before replacing files. Preserve `.env`, `.venv`, `face_landmarker.task`, `events.sqlite3` and related journal files. Do not copy an empty journal over existing records.

## Install and start

On the Pi:

```bash
cd "$HOME/DriveAlert Device"
bash setup_pi.sh
.venv/bin/python device.py
```

Installation needs internet for OS/Python dependencies and the model when absent. Picamera2 uses the system camera libraries. The service normally runs headlessly.

Do not start a second process while another instance owns the camera or port 5000. Restart Django after changing its device address or key.

## Boot service

After verifying manual operation, stop the foreground process and run:

```bash
bash install_service.sh
systemctl is-active drivealert-device.service
journalctl -u drivealert-device.service -n 40 --no-pager
```

The installer starts the device API at boot. Monitoring begins from the app. It does not install Django, MySQL or the notification worker as Pi services.

## Acceptance checks

Confirm camera acquisition, calibration, live status, face loss, prolonged closure, event synchronisation and stop behaviour. Verify phone audio using the [phone alert guide](PHONE_ALARMS.md). Keep the laptop awake while it hosts the backend.

A hostname or stable network address can simplify reconnection. Existing services may use a different working directory; inspect their configuration before changing deployment paths.
