import time
from django.core.management.base import BaseCommand, CommandError
from django.db import close_old_connections
from api import push

class Command(BaseCommand):
    help = "Deliver queued Firebase notifications. Run one worker alongside Django."

    def add_arguments(self, parser):
        parser.add_argument("--once", action="store_true")

    def handle(self, *args, **options):
        if not push.configured():
            raise CommandError("Configure FIREBASE_ENABLED and GOOGLE_APPLICATION_CREDENTIALS first.")
        self.stdout.write("DriveAlert notification worker started.")
        try:
            while True:
                close_old_connections()
                processed = push.process_one()
                if options["once"]:
                    break
                if not processed:
                    time.sleep(2)
        except KeyboardInterrupt:
            self.stdout.write("Worker stopped.")

