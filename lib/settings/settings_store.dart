import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/field_math.dart';

/// Detector options, saved with `shared_preferences`.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs)
      : _sensitivity = Sensitivity.fromName(_prefs?.getString(_kSensitivity)),
        _sound = _prefs?.getBool(_kSound) ?? true,
        _vibration = _prefs?.getBool(_kVibration) ?? true,
        _autoRezero = _prefs?.getBool(_kAutoRezero) ?? false;

  /// For tests: keeps everything in memory.
  SettingsStore.memory()
      : _prefs = null,
        _sensitivity = Sensitivity.medium,
        _sound = true,
        _vibration = true,
        _autoRezero = false;

  static const _kSensitivity = 'sensitivity';
  static const _kSound = 'sound';
  static const _kVibration = 'vibration';
  static const _kAutoRezero = 'auto_rezero';

  static Future<SettingsStore> load() async => SettingsStore._(await SharedPreferences.getInstance());

  final SharedPreferences? _prefs;
  Sensitivity _sensitivity;
  bool _sound;
  bool _vibration;
  bool _autoRezero;

  Sensitivity get sensitivity => _sensitivity;
  bool get sound => _sound;
  bool get vibration => _vibration;
  bool get autoRezero => _autoRezero;

  void setSensitivity(Sensitivity v) {
    _sensitivity = v;
    _prefs?.setString(_kSensitivity, v.name);
    notifyListeners();
  }

  void setSound(bool v) {
    _sound = v;
    _prefs?.setBool(_kSound, v);
    notifyListeners();
  }

  void setVibration(bool v) {
    _vibration = v;
    _prefs?.setBool(_kVibration, v);
    notifyListeners();
  }

  void setAutoRezero(bool v) {
    _autoRezero = v;
    _prefs?.setBool(_kAutoRezero, v);
    notifyListeners();
  }
}
