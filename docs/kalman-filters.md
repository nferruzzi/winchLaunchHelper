# Kalman Filter & Speed Projection — Design Decisions

## Why Linear KF, not Extended
The state model is linear: `[position, velocity]` with constant-acceleration assumption. No nonlinear observation or transition functions → a standard Linear KF is correct. The original "ExtendedKalmanFilter" name was misleading. Renamed to `KalmanFilter` (with `typealias ExtendedKalmanFilter = KalmanFilter` for backwards compat).

## Two KF instances
- **Speed KF** (`timeStep: 0.02, q: 5.0, R: 1.0`): fuses GPS speed (1Hz) with accelerometer (50Hz)
- **Altitude KF** (`timeStep: 0.02, q: 2.0, R: 0.5`): fuses barometer pressure (~1Hz) with vertical acceleration (50Hz)

Both use the same `KalmanFilter` struct with different tuning parameters.

## Process Noise Q
Symmetric matrix from constant-acceleration model:
```
Q = q * [[dt⁴/4, dt³/2],
         [dt³/2, dt²  ]]
```
This is rank-1 by construction → determinant is 0 (positive semi-definite, not positive definite). Tests must use `≥ -1e-15` not `> 0`.

## Covariance Update — Joseph Form
Uses Joseph form `P = (I - KH) P (I - KH)' + K R K'` instead of simplified `P = (I - KH) P` for numerical stability. Ensures P remains symmetric and positive definite over many iterations.

## Fundamental Problem: GPS Speed vs Accelerometer
**CLLocation.speed** = horizontal ground speed magnitude (no vertical component).
**CMDeviceMotion.userAcceleration** = 3D acceleration in `xMagneticNorthZVertical` reference frame (X=north, Y=east, Z=up), gravity removed.

During a winch launch, the glider climbs steeply:
- GPS speed *drops* (less horizontal motion)
- Vertical acceleration *increases*
- Fusing horizontal-only GPS with vertical-only accel gives **conflicting signals**

## Solution: Flight Path Projection
Project everything along the flight path using pitch angle from CoreMotion:

### Acceleration projection
```swift
let aHorizontal = sqrt(ax² + ay²)  // horizontal magnitude
let aFlightPath = aHorizontal * cos(pitch) + az * sin(pitch)
```
- At 0° pitch: all horizontal acceleration
- At 90° pitch: all vertical acceleration
- At 45°: both contribute equally

**Known limitation**: `sqrt(ax² + ay²)` loses the sign (always positive). For now acceptable since during launch the glider accelerates forward.

### GPS speed correction
```swift
flightPathSpeed = groundSpeed / cos(pitch)
```
Ground speed is the horizontal projection of flight path speed: `groundSpeed = flightPathSpeed * cos(pitch)`, so we divide to recover the actual speed along the flight path.

Clamped at `cos(pitch) > 0.3` to avoid division by near-zero at extreme pitch angles (>~72°).

### Pitch source
`latestPitch` updated at 50Hz from `DeviceMotionService.pitch` publisher via a dedicated subscription. Used by both the acceleration projection and GPS correction.

## Why Not Barometer for Speed?
Barometer (CMAltimeter) updates at only ~1Hz on iPhone. Too slow to be useful as a direct speed source. Instead, barometer is used for the altitude KF, fused with vertical acceleration at 50Hz.

## QFE Staircase Problem
Before the altitude KF, QFE display showed staircase pattern because barometer updates at ~1Hz. The altitude KF interpolates between barometer readings using vertical acceleration, producing smooth altitude at 50Hz via the same `switchToLatest` pattern as the speed KF.

## Accelerometer Rate
Changed from 10Hz to 50Hz (`deviceMotionUpdateInterval = 1.0/50.0`). Higher rate gives:
- Better KF interpolation between GPS/barometer readings
- Smoother speed and altitude estimates
- More responsive wing drop detection via roll monitoring

## Reference Frame
`CMAttitudeReferenceFrame.xMagneticNorthZVertical`:
- X = magnetic north
- Y = east
- Z = up (vertical)
- userAcceleration is gravity-removed in this frame
