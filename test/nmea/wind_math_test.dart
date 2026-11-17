import 'package:flutter_test/flutter_test.dart';
import 'package:sail_performance/nmea/wind_math.dart';

void main() {
  group('normalizeDegrees / circularDeltaDegrees', () {
    test('wraps negative and large angles', () {
      expect(normalizeDegrees(-10), closeTo(350, 1e-9));
      expect(normalizeDegrees(370), closeTo(10, 1e-9));
    });

    test('shortest clockwise delta across 0°', () {
      expect(circularDeltaDegrees(350, 10), closeTo(20, 1e-9));
      expect(circularDeltaDegrees(10, 350), closeTo(-20, 1e-9));
    });
  });

  group('vectorMeanDegrees', () {
    test('averages around north without pulling south', () {
      final mean = vectorMeanDegrees([350, 10]);
      expect(mean, isNotNull);
      expect(mean!, closeTo(0, 1e-6));
    });
  });

  group('computeTwd', () {
    test('heading + signed TWA mod 360', () {
      expect(
        computeTwd(headingDegrees: 45, twaSignedDegrees: 32),
        closeTo(77, 1e-9),
      );
      expect(
        computeTwd(headingDegrees: 10, twaSignedDegrees: -30),
        closeTo(340, 1e-9),
      );
    });
  });

  group('evaluateLiftHeader', () {
    test('starboard: clockwise TWD is a lift', () {
      final r = evaluateLiftHeader(
        smoothedTwdDegrees: 90,
        referenceTwdDegrees: 80,
        twaSignedDegrees: 35,
      );
      expect(r.isLift, isTrue);
      expect(r.onStarboard, isTrue);
      expect(r.deltaDegrees, closeTo(10, 1e-9));
      expect(r.label, 'Lift +10°');
    });

    test('starboard: counter-clockwise TWD is a header', () {
      final r = evaluateLiftHeader(
        smoothedTwdDegrees: 70,
        referenceTwdDegrees: 80,
        twaSignedDegrees: 35,
      );
      expect(r.isLift, isFalse);
      expect(r.label, 'Header −10°');
    });

    test('port: counter-clockwise TWD is a lift', () {
      final r = evaluateLiftHeader(
        smoothedTwdDegrees: 70,
        referenceTwdDegrees: 80,
        twaSignedDegrees: -35,
      );
      expect(r.onStarboard, isFalse);
      expect(r.isLift, isTrue);
      expect(r.label, 'Lift +10°');
    });

    test('port: clockwise TWD is a header', () {
      final r = evaluateLiftHeader(
        smoothedTwdDegrees: 90,
        referenceTwdDegrees: 80,
        twaSignedDegrees: -35,
      );
      expect(r.isLift, isFalse);
      expect(r.label, 'Header −10°');
    });
  });
}
