"""Store a reference to a private service-account file, never its contents."""
import argparse
import json
from pathlib import Path

def configure(path):
    source = Path(path).expanduser().resolve()
    data = json.loads(source.read_text(encoding="utf-8"))
    if data.get("type") != "service_account" or data.get("project_id") != "drivealert-36c76" or not data.get("private_key"):
        raise SystemExit("Expected a Firebase service-account key for drivealert-36c76.")
    target = Path(__file__).with_name("backend") / ".env"
    entries = {
        "FIREBASE_ENABLED": "true",
        "FIREBASE_PROJECT_ID": "drivealert-36c76",
        "GOOGLE_APPLICATION_CREDENTIALS": "'" + source.as_posix().replace("'", "\\'") + "'",
    }
    lines = target.read_text(encoding="utf-8").splitlines() if target.exists() else []
    remaining = set(entries)
    for i, line in enumerate(lines):
        name = line.split("=", 1)[0]
        if name in entries:
            lines[i] = name + "=" + entries[name]
            remaining.discard(name)
    lines.extend(name + "=" + entries[name] for name in sorted(remaining))
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Firebase backend credential reference saved. No private key was copied.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", help="Path to your private service-account JSON")
    options = parser.parse_args()
    configure(options.credentials or input("Private Firebase service-account JSON path: ").strip().strip('"'))

