# Metal (package: metal / com.itsash.metal)

Metal detector for Android. Reads the phone's magnetometer and shows how far the
field deviates from a zero point (baseline), with a meter, a 10 s graph, a tone
and vibration. Finds ferromagnetic metal (iron, steel, nickel) and magnets, not
aluminium, copper, gold or silver. Single screen plus Help and Settings. The
window keeps the screen on while `HomeScreen` is alive.

## Code layout

- `lib/core/`: pure Dart, unit tested (`test/`). Add a test for every change.
  - `field_math.dart`: `Vec3`, `FieldFilter` (exponential smoothing by time
    constant), `Sensitivity` (threshold and full scale in µT), `DeviationHistory`
    (50 ms buckets, 10 s), `DetectorEngine` (needsZero -> calibrating -> ready;
    baseline = mean of raw samples over 1.5 s, retried when the spread is
    over 2 µT; deviation = |smoothed field - baseline|; hysteresis at 70%;
    optional auto re-zero that follows drift only while the deviation is below
    half the threshold).
  - `tone_mapping.dart`: `feedbackFor` maps deviation to pitch (400..1600 Hz,
    exponential) and beep period (700 ms down to 70 ms, continuous near full
    scale); silent below the threshold.
- `lib/platform/device_channel.dart`: `Device` interface (faked in tests) and
  `DeviceChannel` over `com.itsash.metal/device` (methods `keepScreenOn`,
  `vibrate`, `setTone`, `stopTone`) and event channel `/field`
  (`[x, y, z, accuracy, uncalibrated]`). Native errors become `SensorUnavailable`.
- `lib/settings/settings_store.dart`: sensitivity, sound, vibration, auto re-zero
  (`shared_preferences`).
- `lib/screens/`: `home_screen` (sensor subscription, throttled UI at 25 Hz,
  feedback), `help_screen`, `settings_screen` (ends with `UiAppearanceSection`,
  `UiUpdateSection(storeId: 'metal')`, `UiDeveloperSection()`).
- `lib/widgets/deviation_meter.dart`: number, bar and threshold line.
- `android/app/src/main/kotlin/com/itsash/metal/`: `MainActivity.kt`,
  `MagnetStreamHandler.kt` (prefers `TYPE_MAGNETIC_FIELD_UNCALIBRATED` so the OS
  hard-iron calibration cannot absorb metal; falls back to the calibrated sensor;
  100 Hz), `ToneGenerator.kt` (`AudioTrack` sine with beep gating and fades).

## Commands

- `make run`, `make build` (release APK), `make test` (`flutter analyze` +
  `flutter test`), `make clean`.
- Icon: SVG sources in `assets/icon/` (`logo`, `logo_foreground`,
  `logo_background`; a pixel horseshoe magnet) -> `rsvg-convert -w 1024 -h 1024`
  to `*-1024.png`, then `dart run flutter_launcher_icons`.

## Conventions

- minSdk 26. UI only from the shared `theme` package (`../theme`, read
  `../theme/COMPONENTS.md`); no hardcoded colors. Starts in light mode.
- Permissions: `INTERNET` (update check only), `VIBRATE`. No analytics.
- The sensor is optional (`uses-feature required=false`); without a magnetometer
  the home screen shows a "No magnetometer" message.
- Sampling is capped at 100 Hz to avoid needing `HIGH_SAMPLING_RATE_SENSORS`.

## Release (Ash Store)

- `store.json` (id `metal`, repo its-ash/metal), `store.mk`, `index.html` +
  `CNAME` (`metal.itsash.in`). See `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version -> build -> commit, tag `vX.Y.Z`, push -> GitHub
  release with `metal.apk` -> topics, homepage, Pages. Never create releases,
  tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run
  `make store-sync` at the workspace root.
