import 'package:flutter_test/flutter_test.dart';
import 'package:metal/core/tone_mapping.dart';

FeedbackParams at(double dev) => feedbackFor(deviation: dev, threshold: 4, fullScale: 60);

void main() {
  test('silent below the threshold', () {
    expect(at(0), FeedbackParams.silent);
    expect(at(3.99), FeedbackParams.silent);
  });

  test('just above the threshold: low pitch, slow beeps', () {
    final p = at(4);
    expect(p.active, isTrue);
    expect(p.freqHz, closeTo(minToneHz, 1e-6));
    expect(p.periodMs, slowestBeepMs);
  });

  test('at full scale: top pitch and continuous tone', () {
    final p = at(60);
    expect(p.freqHz, closeTo(maxToneHz, 1e-6));
    expect(p.periodMs, 0);
    expect(at(500), p);
  });

  test('pitch rises and beeps speed up with deviation', () {
    var prev = at(4);
    for (final d in [8.0, 15.0, 25.0, 35.0, 45.0]) {
      final p = at(d);
      expect(p.freqHz, greaterThan(prev.freqHz));
      expect(p.periodMs, lessThan(prev.periodMs));
      prev = p;
    }
  });

  test('pitch doubles every half of the range (exponential)', () {
    final mid = at(32); // x = 0.5 -> one octave up
    expect(mid.freqHz, closeTo(800, 1));
  });

  test('beeps are continuous in the top 15 percent of the range', () {
    expect(at(60 - 0.1 * 56).periodMs, 0);
    expect(at(10).periodMs, greaterThan(0));
  });

  test('degenerate range stays silent', () {
    expect(feedbackFor(deviation: 10, threshold: 10, fullScale: 10), FeedbackParams.silent);
  });

  test('vibration period follows the beeps, 120 ms when continuous', () {
    expect(vibrationPeriodMs(at(10)), at(10).periodMs);
    expect(vibrationPeriodMs(at(60)), 120);
  });
}
