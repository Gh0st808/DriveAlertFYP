#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f .env ]; then
  printf '%s\n' "Copy the paired .env created by configure.py into this device folder first."
  exit 1
fi
sudo apt-get update
sudo apt-get install -y python3-venv python3-picamera2 python3-opencv python3-pygame
python3 -m venv --system-site-packages .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python download_model.py
.venv/bin/python -m unittest test_device -v
printf '%s\n' "Device ready. Start with: .venv/bin/python device.py"

