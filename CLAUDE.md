# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Winch Launch Helper (bundle: `glider.ninja.winch.launch`) — an iOS SwiftUI app that assists glider pilots during winch launches. It provides real-time attitude, speed, altitude (QFE), and remaining runway distance using device sensors (CoreMotion, CoreLocation, barometer). It includes configurable voice callouts at key altitudes and speed thresholds.

## Build & Run

- **Xcode project**: `AHIS.xcodeproj` (no SPM/CocoaPods dependencies)
- **Target**: iOS 17.0+, Swift 5
- **Build**: `xcodebuild -scheme AHIS -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Unit Tests**: scheme `AHIS`, test files in `Winch Launch Tests/` (KalmanFilterTests, MachineStateTests, WingDropTests)
- **UI Tests**: scheme `AHIS`, test files in `Winch Launch UITests/`
- **Fastlane screenshots**: `bundle exec fastlane screenshots`
- **Fastlane beta** (bump build number + tag): `bundle exec fastlane beta`

## Architecture

### Sensor Data Pipeline

All sensor data flows through Combine publishers using a generic `DataPoint<Value>` wrapper that pairs a value with a `DataPointTimeInterval` (supports both absolute `Date` and relative `TimeInterval` for replay).

Accelerometer runs at **50Hz** (`deviceMotionUpdateInterval = 1.0/50.0`). GPS speed arrives at ~1Hz, barometer at ~1Hz.

**Key type aliases** (in `DataPoint.swift`):
`DataPointSpeed`, `DataPointAngle`, `DataPointAltitude`, `DataPointAcceleration`, `DataPointPressure`, `DataPointLocation`, `DataPointUserAcceleration`

### Kalman Filter (`Services/ExtendedKalmanFilter.swift`)

Generic `KalmanFilter` struct with state `[position, velocity]`, used for both speed and altitude fusion. See [`docs/kalman-filters.md`](docs/kalman-filters.md) for detailed design decisions including:
- Why Linear KF (not Extended) — the model is linear
- Flight path projection: acceleration projected along pitch, GPS speed corrected by `1/cos(pitch)`
- Joseph form covariance update for numerical stability
- Two instances: Speed KF (GPS + accel) and Altitude KF (barometer + vertical accel)
- QFE staircase fix via altitude KF interpolation at 50Hz

### Service Layer (protocol-driven, in `Services/`)

- **`DeviceMotionProtocol`** — defines Combine publishers for all sensor streams (roll, pitch, heading, speed, altitude, pressure, location, userAcceleration). Three implementations:
  - `DeviceMotionService` — live device sensors (CoreMotion + CoreLocation + barometer) at 50Hz
  - `ReplayDeviceMotionService` — replays recorded JSON sensor dumps via Timer
  - `MockedDeviceMotionService` — for previews/tests

- **`MachineStateProtocol` / `MachineStateService`** — state machine tracking launch phases: `waiting → takingOff → minSpeedReached ⇄ minSpeedLost → maxSpeedReached → completed/aborted`. Hysteresis of 5 km/h on all speed transitions to prevent chatty callouts. Transition logic extracted into pure static `transition()` function for testability.

### ViewModel

- **`AHServiceViewModel`** — bridges services to SwiftUI. Key responsibilities:
  - Subscribes to all sensor + state publishers
  - Manages altitude history and voice callouts (AVSpeechSynthesizer)
  - Configurable speech rate, callout messages, altitude thresholds (all persisted via UserDefaults)
  - **Wing drop detection**: pure static `shouldAnnounceWingDrop()` function, monitors roll at 50Hz during `takingOff`/`minSpeedReached`/`minSpeedLost`, announced once per launch
  - Voice callouts: "minima" (min speed reached), "più" (min speed lost), "meno" (overspeed), altitude callouts, "ala" (wing drop), max altitude at completion — all configurable
  - Sensor recording/dump to JSON

### Views (in `Views/`)

- `ContentView` — root view, portrait/landscape layout switching
- `AttitudeIndicatorView` — artificial horizon (uses `SkyShape`, `EarthShape`, `TriangleShape`)
- `WinchLaunchView` — speed, altitude, state, acceleration display
- `LaunchProfileView` — altitude history chart
- `WinchLengthView` / `WinchLengthShape` — remaining runway distance bar
- `HeadingIndicatorView` — compass heading (landscape only)
- `SettingsView` — min/max speed, winch length, units, recording toggle, replay file picker
- `AlertsSettingsView` — speech rate, altitude callout configuration (add/remove), per-callout toggle and message editing
- `DisclaimerView` — full-screen disclaimer shown on first launch

### App Entry Point

`AHISApp.swift` — `Services` singleton holds the active `DeviceMotionProtocol` and `MachineStateService`, and can switch between live and replay mode via `setup(replay:)`. Shows `DisclaimerView` on first launch (persisted via `@AppStorage("disclaimerAccepted")`).

### User Settings (UserDefaults keys)

- Min/max speed, winch length, pitch/roll zero calibration, recording toggle
- Speech rate, callout messages (minima, più, meno, ala), per-callout enabled flags
- Configured altitude callouts (array of Int meters)
- Disclaimer accepted flag
- Speed/altitude unit preferences

## Tests

- **KalmanFilterTests** (24 tests): initial state, Q symmetry/positive semi-definiteness, predict/update cycles, convergence, speed/altitude KF scenarios, numerical stability, flight path projection math, GPS correction math
- **MachineStateTests** (21 tests): all transitions, hysteresis, always-pass-through-minSpeedReached, full launch scenarios
- **WingDropTests** (14 tests): detection in monitored states, negative roll, threshold boundary, non-monitored states, already announced, custom threshold

## Sensor Recording & Replay

The app can record sensor data to JSON files (saved to Documents directory) and replay them. Recordings are trimmed around takeoff time and normalized. To replay a bundled recording during development, change the initializer in `AHISApp.swift` to use `ReplayDeviceMotionService(bundle: "filename.json")`.

## Design Documentation

- [`docs/kalman-filters.md`](docs/kalman-filters.md) — Kalman filter design, sensor fusion, flight path projection rationale
