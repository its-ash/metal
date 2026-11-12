# Metal

Metal detector for studs, nails, pipes and rebar, using your phone's magnetometer.

**[Website](https://metal.itsash.in)** · **[Download APK](https://github.com/its-ash/metal/releases/latest/download/metal.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Live deviation meter**: the change in the magnetic field from a zero point, as a big number in µT, a bar and a detection threshold line.
- **Zero**: averages the field for about 1.5 seconds with the phone held still. It retries if the phone moves, and an optional auto re-zero follows slow drift.
- **Sensitivity**: low, medium and high, with a live graph of the last 10 seconds.
- **Tone and vibration**: pitch and beep rate rise as you get closer to metal. Each can be switched off.
- **Raw sensor**: uses the uncalibrated magnetometer when the phone has one, so Android's own calibration cannot absorb the metal. It falls back to the calibrated sensor.
- **Honest help**: finds iron, steel, nickel and magnets. It does not find aluminium, copper, gold or silver.
- **Private**: no accounts, no ads. The only network call is the update check in Settings.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Metal from it.
- **APK**: download the [latest APK](https://github.com/its-ash/metal/releases/latest/download/metal.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) and a phone with a magnetometer.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make build    # release APK
make test     # flutter analyze + flutter test
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `metal.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart                    # UiApp + HomeScreen
├── core/                        # pure, tested logic
│   ├── field_math.dart          # Vec3, smoothing, baseline, deviation, history, DetectorEngine
│   └── tone_mapping.dart        # deviation -> pitch / beep rate
├── platform/device_channel.dart # magnetometer stream, tone, vibration, keep-screen-on
├── settings/settings_store.dart # sensitivity, sound, vibration, auto re-zero
├── widgets/deviation_meter.dart
└── screens/                     # home, help, settings
android/app/src/main/kotlin/com/itsash/metal/
├── MainActivity.kt              # channels, vibrator
├── MagnetStreamHandler.kt       # uncalibrated magnetometer at 100 Hz
└── ToneGenerator.kt             # AudioTrack sine tone with beep gating
```

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
