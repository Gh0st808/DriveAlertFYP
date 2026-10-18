"""Retry metadata delivery independently of camera processing and the app screen."""
import json
import os
from urllib.request import Request, urlopen

def send_pending(journal):
    base = os.getenv("BACKEND_URL", "").rstrip("/")
    key = os.getenv("DEVICE_API_KEY", "")
    if not base or not key:
        return
    for item in journal.pending():
        try:
            request = Request(base + "/device/events/", method="POST",
                headers={"Content-Type": "application/json", "X-Device-Key": key},
                data=json.dumps({"run_id": item["run_id"], "event": item["event"]}).encode())
            with urlopen(request, timeout=3) as response:
                saved = json.loads(response.read()).get("saved") is True
            if saved:
                journal.acknowledged(item["id"])
            else:
                journal.defer(item["id"])
        except (OSError, ValueError):
            journal.defer(item["id"])

def sender_loop(journal, stopped):
    while not stopped.is_set():
        send_pending(journal)
        stopped.wait(5)
