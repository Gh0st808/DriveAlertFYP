# DriveAlert backend

Django REST API for accounts, devices, sessions, detection events, reports, notifications and AI assistant requests.

## Configuration

Use the root setup guide to create local environment settings. MySQL is the default database. Apply the repository migrations with the configured environment; preserve existing records and migration history.

The app authenticates using JWT. Device communication uses DEVICE_URL, DEVICE_SERIAL_NUMBER and DEVICE_API_KEY.

## Tests

```powershell
python manage.py test api --settings=config.test_settings
python manage.py makemigrations --check --dry-run --settings=config.test_settings
```

The test settings select an isolated SQLite database. Flask/device dependencies are needed for the protocol integration tests.

The default email backend prints password-reset links to the terminal. SMTP settings are required for inbox delivery.

- [Setup](../docs/SETUP.md)
- [Cloud configuration](../docs/configuration/CLOUD.md)
- [ILMU configuration](../docs/configuration/ILMU.md)
- [Validation](../docs/testing/VALIDATION.md)
