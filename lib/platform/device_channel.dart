import 'dart:async';

import 'package:flutter/services.dart';

import '../core/field_math.dart';
import '../core/tone_mapping.dart';

const _base = 'com.itsash.metal';

/// The magnetometer cannot be used on this device.
class SensorUnavailable implements Exception {
  const SensorUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One magnetometer sample.
class FieldSample {
  const FieldSample(this.field, this.accuracy, this.uncalibrated);

  /// Field in µT.
  final Vec3 field;

  /// Android sensor accuracy: 0 unreliable .. 3 high.
  final int accuracy;

  /// True when the raw (uncalibrated) sensor is used.
  final bool uncalibrated;
}

/// Access to the magnetometer, the tone generator, the vibrator and the window.
abstract class Device {
  /// Starts the magnetometer when listened to and releases it when cancelled.
  Stream<FieldSample> field();

  Future<void> keepScreenOn(bool on);
  Future<void> vibrate(int ms);
  Future<void> setTone(FeedbackParams p);
  Future<void> stopTone();
}

class DeviceChannel implements Device {
  const DeviceChannel();

  static const _device = MethodChannel('$_base/device');
  static const _field = EventChannel('$_base/field');

  @override
  Stream<FieldSample> field() => _field.receiveBroadcastStream().map((e) {
        final v = (e as List).cast<num>();
        return FieldSample(
          Vec3(v[0].toDouble(), v[1].toDouble(), v[2].toDouble()),
          v[3].toInt(),
          v[4].toInt() == 1,
        );
      }).transform(
        StreamTransformer<FieldSample, FieldSample>.fromHandlers(
          handleError: (error, stack, sink) {
            const message = 'This phone has no magnetometer.';
            if (error is PlatformException) {
              sink.addError(SensorUnavailable(error.message ?? message), stack);
            } else if (error is MissingPluginException) {
              sink.addError(const SensorUnavailable(message), stack);
            } else {
              sink.addError(error, stack);
            }
          },
        ),
      );

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _device.invokeMethod<void>(method, args);
    } on PlatformException {
      // Feedback is best effort.
    } on MissingPluginException {
      // No native side (tests).
    }
  }

  @override
  Future<void> keepScreenOn(bool on) => _call('keepScreenOn', on);

  @override
  Future<void> vibrate(int ms) => _call('vibrate', ms);

  @override
  Future<void> setTone(FeedbackParams p) => _call('setTone', [p.freqHz, p.periodMs]);

  @override
  Future<void> stopTone() => _call('stopTone');
}
