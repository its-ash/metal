import 'dart:math' as math;

/// A magnetic field vector in microtesla (µT), in the phone's frame.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 scale(double k) => Vec3(x * k, y * k, z * k);

  /// Length of the vector (field strength in µT).
  double get length => math.sqrt(x * x + y * y + z * z);

  @override
  bool operator ==(Object other) => other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// Exponential smoothing of a vector with a time constant, so the result does
/// not depend on the sensor's sample rate.
class FieldFilter {
  FieldFilter({this.tauMs = 60});

  /// Time constant in milliseconds. Larger = smoother and slower.
  final double tauMs;

  Vec3? _value;

  Vec3? get value => _value;

  void reset() => _value = null;

  /// Feeds one sample that came [dtMs] after the previous one.
  Vec3 add(Vec3 sample, double dtMs) {
    final prev = _value;
    if (prev == null) return _value = sample;
    final dt = dtMs.clamp(0.0, 500.0);
    final alpha = 1 - math.exp(-dt / tauMs);
    return _value = prev + (sample - prev).scale(alpha);
  }
}

/// How easily small disturbances are reported. All values are in µT of
/// deviation from the baseline.
enum Sensitivity {
  low('Low', threshold: 8, fullScale: 150),
  medium('Medium', threshold: 4, fullScale: 60),
  high('High', threshold: 1.5, fullScale: 25);

  const Sensitivity(this.label, {required this.threshold, required this.fullScale});

  final String label;

  /// Deviation at which metal is reported (feedback starts).
  final double threshold;

  /// Deviation that fills the meter and gives the strongest feedback.
  final double fullScale;

  /// Deviation below which tracking the baseline (auto re-zero) is allowed.
  double get trackBand => threshold * 0.5;

  static Sensitivity fromName(String? name) =>
      Sensitivity.values.firstWhere((s) => s.name == name, orElse: () => Sensitivity.medium);
}

/// Where the engine is in its life.
enum DetectorPhase {
  /// No baseline yet. Waiting for the user to tap Zero.
  needsZero,

  /// Averaging samples into the baseline.
  calibrating,

  /// Baseline set; deviation is meaningful.
  ready,
}

/// The result of processing one sample.
class Reading {
  const Reading({
    required this.phase,
    required this.magnitude,
    required this.deviation,
    required this.level,
    required this.detected,
    required this.calibrationProgress,
    required this.unsteady,
  });

  final DetectorPhase phase;

  /// Smoothed field strength in µT.
  final double magnitude;

  /// Length of (smoothed field - baseline) in µT. 0 until the baseline is set.
  final double deviation;

  /// Deviation scaled to 0..1 for the meter, using the sensitivity range.
  final double level;

  /// True while the deviation is above the threshold (with hysteresis).
  final bool detected;

  /// 0..1 while calibrating.
  final double calibrationProgress;

  /// True when the last calibration attempt moved too much and is retried.
  final bool unsteady;

  static const idle = Reading(
    phase: DetectorPhase.needsZero,
    magnitude: 0,
    deviation: 0,
    level: 0,
    detected: false,
    calibrationProgress: 0,
    unsteady: false,
  );
}

/// Deviation values over the last few seconds, one value per time bucket
/// (the largest deviation seen inside it), for the live graph.
class DeviationHistory {
  DeviationHistory({this.windowMs = 10000, this.bucketMs = 50}) : _capacity = windowMs ~/ bucketMs;

  final int windowMs;
  final int bucketMs;
  final int _capacity;
  final List<double> _done = [];
  int _bucket = -1;
  double _current = 0;

  /// Oldest first, including the bucket still being filled.
  List<double> get values => [..._done, if (_bucket >= 0) _current];

  void clear() {
    _done.clear();
    _bucket = -1;
    _current = 0;
  }

  void add(int tMs, double value) {
    final b = tMs ~/ bucketMs;
    if (_bucket < 0) {
      _bucket = b;
      _current = value;
      return;
    }
    if (b == _bucket) {
      _current = math.max(_current, value);
      return;
    }
    // Close the current bucket, and fill any gap with the previous value.
    _done.add(_current);
    final gap = math.min(b - _bucket - 1, _capacity);
    for (var i = 0; i < gap; i++) {
      _done.add(0);
    }
    _bucket = b;
    _current = value;
    while (_done.length >= _capacity) {
      _done.removeAt(0);
    }
  }
}

/// Turns raw magnetometer samples into a deviation from a baseline.
///
/// Pure Dart: feed it samples with a millisecond clock. Steps:
/// 1. Smooth the field ([FieldFilter]).
/// 2. After [zero], average raw samples for [calibrationMs] into the baseline
///    (retried when the phone moves too much).
/// 3. deviation = |smoothed field - baseline|. A vector difference also reacts
///    to metal that only changes the field's direction.
/// 4. Optionally ([autoRezero]) let the baseline follow slow drift while the
///    deviation is small.
class DetectorEngine {
  DetectorEngine({
    this.sensitivity = Sensitivity.medium,
    this.autoRezero = false,
    this.calibrationMs = 1500,
    this.unsteadyStd = 2.0,
    this.maxCalibrationTries = 3,
    this.trackTauMs = 6000,
    double filterTauMs = 60,
  }) : _filter = FieldFilter(tauMs: filterTauMs);

  Sensitivity sensitivity;
  bool autoRezero;
  final int calibrationMs;

  /// Largest allowed spread (µT) of the samples in a calibration window.
  final double unsteadyStd;
  final int maxCalibrationTries;

  /// Time constant of the baseline drift following.
  final double trackTauMs;

  final FieldFilter _filter;
  final DeviationHistory history = DeviationHistory();

  DetectorPhase _phase = DetectorPhase.needsZero;
  Vec3 _baseline = Vec3.zero;
  bool _detected = false;
  bool _unsteady = false;
  int? _lastT;

  // Calibration accumulators.
  int? _calStart;
  int _calCount = 0;
  Vec3 _calSum = Vec3.zero;
  double _calSumSq = 0;
  int _calTries = 0;

  DetectorPhase get phase => _phase;
  Vec3 get baseline => _baseline;
  bool get hasBaseline => _phase == DetectorPhase.ready;

  /// Starts a new calibration with the next samples.
  void zero() {
    _phase = DetectorPhase.calibrating;
    _calTries = 0;
    _unsteady = false;
    _detected = false;
    _resetWindow();
  }

  /// Forgets the baseline and the graph.
  void reset() {
    _phase = DetectorPhase.needsZero;
    _detected = false;
    _unsteady = false;
    _lastT = null;
    _filter.reset();
    history.clear();
    _resetWindow();
  }

  void _resetWindow() {
    _calStart = null;
    _calCount = 0;
    _calSum = Vec3.zero;
    _calSumSq = 0;
  }

  /// Processes one sample taken at [tMs] (any monotonic millisecond clock).
  Reading feed(Vec3 sample, int tMs) {
    final last = _lastT;
    _lastT = tMs;
    final dt = last == null ? 0.0 : (tMs - last).toDouble();
    final smooth = _filter.add(sample, dt);
    final magnitude = smooth.length;

    if (_phase == DetectorPhase.calibrating) {
      return _calibrate(sample, magnitude, tMs);
    }
    if (_phase == DetectorPhase.needsZero) {
      return Reading(
        phase: _phase,
        magnitude: magnitude,
        deviation: 0,
        level: 0,
        detected: false,
        calibrationProgress: 0,
        unsteady: false,
      );
    }

    final dev = (smooth - _baseline).length;
    if (autoRezero && dev < sensitivity.trackBand && dt > 0) {
      final alpha = 1 - math.exp(-dt.clamp(0.0, 500.0) / trackTauMs);
      _baseline = _baseline + (smooth - _baseline).scale(alpha);
    }

    final t = sensitivity.threshold;
    _detected = _detected ? dev >= t * 0.7 : dev >= t;
    history.add(tMs, dev);
    return Reading(
      phase: _phase,
      magnitude: magnitude,
      deviation: dev,
      level: (dev / sensitivity.fullScale).clamp(0.0, 1.0),
      detected: _detected,
      calibrationProgress: 1,
      unsteady: _unsteady,
    );
  }

  Reading _calibrate(Vec3 sample, double magnitude, int tMs) {
    final start = _calStart ??= tMs;
    _calCount++;
    _calSum = _calSum + sample;
    _calSumSq += sample.x * sample.x + sample.y * sample.y + sample.z * sample.z;

    final elapsed = tMs - start;
    if (elapsed >= calibrationMs && _calCount >= 5) {
      final mean = _calSum.scale(1 / _calCount);
      final variance = math.max(0.0, _calSumSq / _calCount - (mean.x * mean.x + mean.y * mean.y + mean.z * mean.z));
      final std = math.sqrt(variance);
      _calTries++;
      if (std > unsteadyStd && _calTries < maxCalibrationTries) {
        _unsteady = true;
        _resetWindow();
      } else {
        _baseline = mean;
        _phase = DetectorPhase.ready;
        history.clear();
        // Keep _unsteady if we gave up waiting, so the UI can warn.
        _unsteady = std > unsteadyStd;
        _resetWindow();
        return Reading(
          phase: _phase,
          magnitude: magnitude,
          deviation: 0,
          level: 0,
          detected: false,
          calibrationProgress: 1,
          unsteady: _unsteady,
        );
      }
    }
    return Reading(
      phase: DetectorPhase.calibrating,
      magnitude: magnitude,
      deviation: 0,
      level: 0,
      detected: false,
      calibrationProgress: (elapsed / calibrationMs).clamp(0.0, 1.0),
      unsteady: _unsteady,
    );
  }
}
