# DriveAlert Django backend

Use the project root configure.py and setup_backend.ps1 instructions before starting.

The default database is MySQL. Migrations 0001–0003 are preserved; migration 0004 adds profile preferences, vehicle model, Pi run IDs and idempotent event IDs.

Tests with an isolated SQLite database:

```powershell
python manage.py test api --settings=config.test_settings
python manage.py makemigrations --check --dry-run --settings=config.test_settings
```

Install the device requirements as well to run the two optional Flask protocol integration tests. Without Flask those tests are skipped.

The app authenticates with JWT. Django talks to the Pi using DEVICE_URL, DEVICE_SERIAL_NUMBER and DEVICE_API_KEY from .env.

The default email backend prints reset links in the terminal. Set SMTP environment variables for real email delivery.

The root README explains network configurations and safe migration handling.

