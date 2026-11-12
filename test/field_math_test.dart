import 'package:flutter_test/flutter_test.dart';
import 'package:metal/core/field_math.dart';

/// Feeds [count] samples [stepMs] apart, starting at [t0]. Returns the last reading.
Reading feedConst(DetectorEngine e, Vec3 v, int t0, int count, {int stepMs = 10}) {
  late Reading r;
  for (var i = 0; i < count; i++) {
    r = e.feed(v, t0 + i * stepMs);
  }
  return r;
}

void main() {
  const earth = Vec3(20, -10, 40);

  group('Vec3', () {
    test('length is the euclidean norm', () {
      expect(const Vec3(3, 4, 0).length, 5);
      expect(const Vec3(1, 2, 2).length, 3);
    });
    test('arithmetic', () {
      expect(const Vec3(1, 2, 3) + const Vec3(1, 1, 1), const Vec3(2, 3, 4));
      expect(const Vec3(1, 2, 3) - const Vec3(1, 1, 1), const Vec3(0, 1, 2));
      expect(const Vec3(1, 2, 3).scale(2), const Vec3(2, 4, 6));
    });
  });

  group('FieldFilter', () {
    test('first sample passes through', () {
      expect(FieldFilter().add(earth, 10), earth);
    });
    test('converges to a constant input', () {
      final f = FieldFilter(tauMs: 60)..add(Vec3.zero, 0);
      Vec3 v = Vec3.zero;
      for (var i = 0; i < 100; i++) {
        v = f.add(earth, 10);
      }
      expect((v - earth).length, lessThan(0.01));
    });
    test('does not depend on the sample rate', () {
      Vec3 run(double dt, int n) {
        final f = FieldFilter(tauMs: 60)..add(Vec3.zero, 0);
        Vec3 v = Vec3.zero;
        for (var i = 0; i < n; i++) {
          v = f.add(earth, dt);
        }
        return v;
      }

      expect((run(10, 30) - run(5, 60)).length, lessThan(0.01));
    });
    test('reset forgets the history', () {
      final f = FieldFilter()..add(earth, 10);
      f.reset();
      expect(f.value, isNull);
    });
  });

  group('DetectorEngine', () {
    test('waits for zero and reports no deviation', () {
      final e = DetectorEngine();
      final r = feedConst(e, earth, 0, 20);
      expect(r.phase, DetectorPhase.needsZero);
      expect(r.deviation, 0);
      expect(r.magnitude, closeTo(earth.length, 0.01));
    });

    test('calibration averages for the configured time', () {
      final e = DetectorEngine()..zero();
      var r = feedConst(e, earth, 0, 50); // 490 ms
      expect(r.phase, DetectorPhase.calibrating);
      expect(r.calibrationProgress, closeTo(0.33, 0.02));
      r = feedConst(e, earth, 500, 110); // past 1500 ms
      expect(r.phase, DetectorPhase.ready);
      expect(e.baseline.x, closeTo(earth.x, 1e-6));
      expect(e.baseline.z, closeTo(earth.z, 1e-6));
    });

    test('deviation is the length of the field change', () {
      final e = DetectorEngine()..zero();
      feedConst(e, earth, 0, 200);
      final r = feedConst(e, earth + const Vec3(0, 0, 30), 2000, 100);
      expect(r.deviation, closeTo(30, 0.1));
      expect(r.detected, isTrue);
    });

    test('reacts to a pure direction change at constant magnitude', () {
      final e = DetectorEngine()..zero();
      feedConst(e, const Vec3(0, 0, 50), 0, 200);
      final r = feedConst(e, const Vec3(50, 0, 0), 2000, 100);
      expect(r.magnitude, closeTo(50, 0.1));
      expect(r.deviation, closeTo(70.7, 0.5));
    });

    test('small noise stays below the threshold', () {
      final e = DetectorEngine()..zero();
      feedConst(e, earth, 0, 200);
      final r = feedConst(e, earth + const Vec3(0.3, 0, 0), 2000, 100);
      expect(r.detected, isFalse);
      expect(r.level, lessThan(0.02));
    });

    test('detection has hysteresis', () {
      final e = DetectorEngine(sensitivity: Sensitivity.medium)..zero(); // threshold 4
      feedConst(e, earth, 0, 200);
      var r = feedConst(e, earth + const Vec3(4.5, 0, 0), 2000, 100);
      expect(r.detected, isTrue);
      r = feedConst(e, earth + const Vec3(3.5, 0, 0), 3000, 100); // between 0.7*4 and 4
      expect(r.detected, isTrue);
      r = feedConst(e, earth + const Vec3(2.0, 0, 0), 4000, 100);
      expect(r.detected, isFalse);
    });

    test('sensitivity changes the level and detection', () {
      Reading run(Sensitivity s) {
        final e = DetectorEngine(sensitivity: s)..zero();
        feedConst(e, earth, 0, 200);
        return feedConst(e, earth + const Vec3(6, 0, 0), 2000, 100);
      }

      expect(run(Sensitivity.low).detected, isFalse);
      expect(run(Sensitivity.medium).detected, isTrue);
      expect(run(Sensitivity.high).level, greaterThan(run(Sensitivity.medium).level));
    });

    test('level is clamped to 0..1', () {
      final e = DetectorEngine()..zero();
      feedConst(e, earth, 0, 200);
      final r = feedConst(e, earth + const Vec3(0, 0, 500), 2000, 100);
      expect(r.level, 1);
    });

    test('a moving phone retries the calibration, then gives up flagged', () {
      final e = DetectorEngine()..zero();
      var t = 0;
      Reading? r;
      // Alternating +-30 µT: far above the unsteady limit.
      for (var i = 0; i < 700; i++) {
        r = e.feed(i.isEven ? const Vec3(30, 0, 0) : const Vec3(-30, 0, 0), t);
        t += 10;
        if (i == 200) {
          expect(r.phase, DetectorPhase.calibrating);
          expect(r.unsteady, isTrue);
        }
      }
      expect(r!.phase, DetectorPhase.ready);
      expect(r.unsteady, isTrue);
    });

    test('zero again replaces the baseline', () {
      final e = DetectorEngine()..zero();
      feedConst(e, earth, 0, 200);
      const other = Vec3(0, 0, 60);
      e.zero();
      final r = feedConst(e, other, 3000, 200);
      expect(e.baseline.z, closeTo(60, 1e-6));
      expect(r.deviation, closeTo(0, 0.1));
    });

    test('reset clears the baseline and the graph', () {
      final e = DetectorEngine()..zero();
      feedConst(e, earth, 0, 200);
      feedConst(e, earth, 2000, 100);
      expect(e.history.values, isNotEmpty);
      e.reset();
      expect(e.phase, DetectorPhase.needsZero);
      expect(e.history.values, isEmpty);
    });

    test('auto re-zero follows slow drift but not a metal object', () {
      final e = DetectorEngine(autoRezero: true, trackTauMs: 2000)..zero();
      feedConst(e, earth, 0, 200);
      // Drift of 1 µT (below track band 2 for medium): baseline follows.
      var r = feedConst(e, earth + const Vec3(1, 0, 0), 2000, 1000);
      expect(r.deviation, lessThan(0.1));
      // A 20 µT object is above the band: never absorbed.
      r = feedConst(e, earth + const Vec3(21, 0, 0), 12000, 1000);
      expect(r.deviation, closeTo(20, 0.5));
    });

    test('without auto re-zero the baseline never moves', () {
      final e = DetectorEngine()..zero();
      feedConst(e, earth, 0, 200);
      final r = feedConst(e, earth + const Vec3(1, 0, 0), 2000, 2000);
      expect(r.deviation, closeTo(1, 0.05));
    });
  });

  group('DeviationHistory', () {
    test('keeps the largest value in a bucket', () {
      final h = DeviationHistory(bucketMs: 50);
      h.add(0, 1);
      h.add(10, 5);
      h.add(20, 2);
      h.add(60, 0.5);
      expect(h.values, [5, 0.5]);
    });

    test('is limited to the window length', () {
      final h = DeviationHistory(windowMs: 1000, bucketMs: 50);
      for (var i = 0; i < 200; i++) {
        h.add(i * 50, i.toDouble());
      }
      expect(h.values.length, lessThanOrEqualTo(20));
      expect(h.values.last, 199);
    });

    test('fills a gap with zeros', () {
      final h = DeviationHistory(bucketMs: 50);
      h.add(0, 3);
      h.add(200, 1);
      expect(h.values, [3, 0, 0, 0, 1]);
    });
  });
}
