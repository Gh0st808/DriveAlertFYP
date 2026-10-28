# System architecture

[← Documentation](README.md)

## Components

The Flutter app authenticates to the Django API using JWT. Django validates ownership and communicates with the Flask device API using the configured device key. The device captures frames, extracts facial landmarks and applies EAR-based detection.

| Component | Data handled |
| --- | --- |
| Flutter | Account interface, monitoring state, frames, reports and preferences |
| Django / MySQL | Users, registered devices, sessions, events and notification records |
| Raspberry Pi | Current frames, calibration state, detection counters and local event journal |

## Detection workflow

1. Start a monitoring run from the app.
2. Capture valid open-eye observations for calibration.
3. Establish an EAR baseline and apply the configured sensitivity.
4. Distinguish brief blinks from longer closures using EAR ratios and elapsed time.
5. Record applicable events and expose status to the backend.
6. Stop the run and synchronise its end time and events.

A sustained closure can produce drowsiness, microsleep and long-closure event types. Counts are limited per type per closure. Losing valid face tracking resets closure timing. See [setup](SETUP.md#detection-thresholds) for the configured thresholds.

## Session consistency

Each run has a UUID shared with its backend session. Device event identifiers support duplicate prevention during retries. The local journal retains event metadata for later synchronisation. Camera frames are not journalled.

The device outbox retries uploads when the backend becomes reachable. A restarted device closes an interrupted run using the stored heartbeat. These mechanisms require testing on the target deployment; see [validation](testing/VALIDATION.md).

## Alerts and reports

The Android monitoring service obtains restricted alarm status through the backend and plays local audio. Cloud notifications use a separate registration and delivery queue. Phone permissions, volume, battery settings and connectivity affect operation.

Reports summarise saved journeys and warning counts. The AI assistant can use an optional account-scoped numeric summary; provider credentials remain on the backend.

## Operating scope

This is a local FYP prototype. Poor lighting can prevent detection, and preview lag has been observed during device testing. Numerical accuracy requires labelled trials. Internet deployment requires production serving, HTTPS and appropriate host, origin and secret configuration.
