"""Create local configuration without embedding existing credentials in the project archive."""
import getpass
import secrets
from pathlib import Path

root = Path(__file__).resolve().parent
backend = root / "backend" / ".env"
device = root / "DriveAlert Device" / ".env"

def quoted(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

def configure():
    if backend.exists() or device.exists():
        raise SystemExit("An .env already exists. Keep it or rename it before running configuration again; no configuration was overwritten.")
    host = input("Backend IP used by your phone [192.168.4.1]: ").strip() or "192.168.4.1"
    pi = input("Pi IP reachable from backend [127.0.0.1 when backend is on Pi]: ").strip() or "127.0.0.1"
    engine = input("Database engine [mysql; enter sqlite only for a separate portable demo]: ").strip() or "mysql"
    if engine not in {"mysql", "sqlite"}:
        raise SystemExit("Database engine must be mysql or sqlite.")
    name = input("MySQL database name [drivealert_db]: ").strip() or "drivealert_db" if engine == "mysql" else ""
    user = input("MySQL user [root]: ").strip() or "root" if engine == "mysql" else ""
    password = getpass.getpass("MySQL password: ") if engine == "mysql" else ""
    key = secrets.token_urlsafe(48)
    text = "\n".join([
        "DJANGO_DEBUG=true", "DJANGO_SECRET_KEY=" + quoted(secrets.token_urlsafe(64)),
        "DJANGO_ALLOWED_HOSTS=" + quoted("localhost,127.0.0.1," + host),
        "DB_ENGINE=" + engine, "DB_NAME=" + quoted(name), "DB_USER=" + quoted(user),
        "DB_PASSWORD=" + quoted(password), "DB_HOST=127.0.0.1", "DB_PORT=3306",
        "DEVICE_URL=" + quoted("http://" + pi + ":5000"),
        "DEVICE_SERIAL_NUMBER=DRIVEALERT-PI-001", "DEVICE_API_KEY=" + quoted(key),
        "CORS_ALLOWED_ORIGINS=http://localhost:8080", "EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend",
        "DEFAULT_FROM_EMAIL=noreply@example.com", ""])
    backend.write_text(text, encoding="utf-8")
    device.write_text("DEVICE_API_KEY=" + key + "\nBACKEND_URL=http://" + host + ":8000/api\nCAMERA_BACKEND=picamera2\nSHOW_PREVIEW=false\nDEVICE_BIND=0.0.0.0\n", encoding="utf-8")
    print("Configuration created. Copy the device folder, including its .env, to the Pi.")
    print("Phone backend address: http://" + host + ":8000/api")
    print("Password reset messages currently appear in the backend console. Configure SMTP to deliver real emails.")

if __name__ == "__main__":
    configure()

