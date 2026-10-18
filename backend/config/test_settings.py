from .settings import *
SECRET_KEY = 'drivealert-test-secret-key-only-for-isolated-tests-at-least-64-characters'
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
ALLOWED_HOSTS = ["testserver", "localhost"]
DEVICE_URL = "http://127.0.0.1:5000"

