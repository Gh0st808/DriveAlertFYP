#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
device_root="$(pwd)"
service_user="$(id -un)"
if [ ! -f .env ] || [ ! -x .venv/bin/python ]; then
  printf '%s\n' "Run setup_pi.sh first."
  exit 1
fi
sudo tee /etc/systemd/system/drivealert-device.service >/dev/null <<EOF
[Unit]
Description=DriveAlert device monitoring API
After=network.target sound.target

[Service]
Type=simple
User=$service_user
WorkingDirectory=$device_root
ExecStart="$device_root/.venv/bin/python" "$device_root/device.py"
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1
SupplementaryGroups=video audio

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now drivealert-device
sudo systemctl status drivealert-device --no-pager

