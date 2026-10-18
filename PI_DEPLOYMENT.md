# Current Pi deployment

Current pairing: Pi user `drivealert`, Pi IP `10.13.1.217`, backend laptop Wi-Fi IP `10.13.1.97`. The backend remains on the laptop for this stage. Phone audio is the alert output. These addresses must be updated if the network changes.

The app and run_app.ps1 now default to http://10.13.1.97:8000/api. Fully restart/rebuild an app previously launched with API_BASE_URL=http://127.0.0.1:8000/api; a compile-time override takes precedence over the source default. For the current phone, use run_app.ps1 -Device R7AX309GLWH -BackendUrl http://10.13.1.97:8000/api. The hotspot LAN connection still needs a real phone test and an appropriate Windows inbound TCP 8000 rule for 10.13.1.0/24. USB forwarding remains an optional development alternative using an explicit 127.0.0.1 override.

The local repair copy has matching backend/device keys in ignored .env files. The ZIP excludes those files and all Firebase/Gemini credentials. When using a fresh extraction, generate matching configuration first; configure.py creates the base pairing. DEVICE_URL on Django should be http://10.13.1.217:5000, and BACKEND_URL on the Pi should be http://10.13.1.97:8000/api. No Firebase Admin JSON or Gemini key is needed in the device folder.

## Transfer from this laptop

On the Pi, enable SSH:

```bash
sudo systemctl enable --now ssh
```

From PowerShell on the laptop, the following copies the source archive and the device-only pairing file. It leaves the original Pi project untouched:

```powershell
$project = 'C:\Users\preet\Documents\Codex\2026-10-16\new-chat-3\work\DriveAlert-Repaired'
$archive = 'C:\Users\preet\Documents\Codex\2026-10-16\new-chat-3\outputs\DriveAlert-Repaired.zip'
scp $archive 'drivealert@10.13.1.217:DriveAlert-Repaired.zip'
scp "$project\DriveAlert Device\.env" 'drivealert@10.13.1.217:drivealert-device.env'
ssh drivealert@10.13.1.217
```

Enter the Pi password locally when prompted; do not paste passwords or .env contents in chat.

## Prepare on the Pi

Extract alongside the old project, then install the pairing file:

```bash
python3 -m zipfile -e "$HOME/DriveAlert-Repaired.zip" "$HOME/DriveAlert-Updated"
cd "$HOME/DriveAlert-Updated/DriveAlert-Repaired/DriveAlert Device"
install -m 600 "$HOME/drivealert-device.env" .env
```

Before starting the new service, stop monitoring and stop the old device process/service so it releases port 5000 and the camera. Inspect existing services with `systemctl list-unit-files 'drivealert*'` and processes with `pgrep -af device.py`; use the known old service name rather than stopping unrelated processes. Keep the old folder as a backup.

Reuse the old model if it exists:

```bash
if [ -f "$HOME/DriveAlert Device/face_landmarker.task" ]; then
  cp "$HOME/DriveAlert Device/face_landmarker.task" face_landmarker.task
fi
```

If the old project has events.sqlite3, preserve it before replacement. After stopping the old process, copy its journal into the updated device folder before starting the new code. Do not copy an actively written database blindly, delete a journal or replace it with an empty one. Older project formats may not have this journal; keep those original records too.

Install and verify:

```bash
bash setup_pi.sh
.venv/bin/python device.py
```

setup_pi.sh needs internet for OS/Python dependencies and the model if not reused. Picamera2 uses system camera libraries; the virtual environment includes system site packages. Default operation is headless. Do not start another copy while the manual server is running.

Restart Django on the laptop to load its paired DEVICE_URL/key. Install the fully rebuilt Android app, open Monitor and verify the camera, calibration and phone audio using PHONE_ALARMS.md. The device serial registered to the signed-in account must match DEVICE_SERIAL_NUMBER (default DRIVEALERT-PI-001); do not re-register a serial already owned by your existing account.

After manual verification, stop the foreground device process with Ctrl+C and install its boot service:

```bash
bash install_service.sh
journalctl -u drivealert-device -f
```

This starts only the device API at Pi boot. Moving Django/database/notification worker to the Pi is a separate deployment step. Keep the laptop backend and current phone connection available during this stage.
