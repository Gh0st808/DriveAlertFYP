# Repository import

The original snapshot below has since been repaired on 18 October 2026. See REPAIR_NOTES_2026-10-18.md for the new changes and their verification limits.

This repository contains the saved `DriveAlert-Repaired.zip` package, last saved on 16 October 2026, imported on 18 October 2026.

It includes the Django backend, Flutter app, Raspberry Pi device code, setup scripts and documentation. Later changes described in conversation or present only on the laptop have not been verified against this snapshot.

Local secrets, databases and a stored profile photo are not included. Configure your own environment using the supplied `.env.example` files and setup guides. Firebase mobile client identifiers are public client configuration, not Firebase Admin credentials.

This import does not modify the separate `Gh0st808/DriveAlert` repository. Import verification checks file integrity; it does not establish that the system runs on the target phone and Pi.

Four optional Flutter web launcher icons were excluded because automated upload review rejected their embedded image metadata. Their web manifest and Apple touch-icon references were removed; Android launcher assets are included.
