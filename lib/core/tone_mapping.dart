import 'dart:math' as math;

/// What the speaker and the vibrator should do for a deviation.
class FeedbackParams {
  const FeedbackParams({required this.active, required this.freqHz, required this.periodMs});

  static const silent = FeedbackParams(active: false, freqHz: 0, periodMs: 0);

  /// False below the threshold: no sound and no vibration.
  final bool active;

  /// Pitch of the tone.
  final double freqHz;

  /// Time between beeps. 0 = continuous tone.
  final int periodMs;

  @override
  bool operator ==(Object other) =>
      other is FeedbackParams && other.active == active && other.freqHz == freqHz && other.periodMs == periodMs;

  @override
  int get hashCode => Object.hash(active, freqHz, periodMs);

  @override
  String toString() => 'FeedbackParams(active: $active, $freqHz Hz, every $periodMs ms)';
}

const double minToneHz = 400;
const double maxToneHz = 1600;
const int slowestBeepMs = 700;
const int fastestBeepMs = 70;

/// Share of the range above the threshold at which beeps merge into one
/// continuous tone.
const double continuousFrom = 0.85;

/// Maps a deviation (µT) to feedback.
///
/// Silent below [threshold]. Above it, pitch rises exponentially from
/// [minToneHz] to [maxToneHz] (2 octaves) and beeps speed up from every
/// [slowestBeepMs] to every [fastestBeepMs], then become continuous near
/// [fullScale].
FeedbackParams feedbackFor({required double deviation, required double threshold, required double fullScale}) {
  if (deviation < threshold || fullScale <= threshold) return FeedbackParams.silent;
  final x = ((deviation - threshold) / (fullScale - threshold)).clamp(0.0, 1.0);
  final freq = minToneHz * math.pow(maxToneHz / minToneHz, x);
  final period = x >= continuousFrom
      ? 0
      : (slowestBeepMs - (slowestBeepMs - fastestBeepMs) * (x / continuousFrom)).round();
  return FeedbackParams(active: true, freqHz: freq.toDouble(), periodMs: period);
}

/// How often to pulse the vibrator for [p] (continuous tone = short pulses).
int vibrationPeriodMs(FeedbackParams p) => p.periodMs == 0 ? 120 : p.periodMs;
