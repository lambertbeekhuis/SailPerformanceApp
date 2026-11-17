import 'package:flutter_test/flutter_test.dart';
import 'package:sail_performance/nmea/wind_shift_tracker.dart';

void main() {
  group('WindShiftTracker', () {
    test('setReferenceNow pins and lift resets near zero', () {
      final tracker = WindShiftTracker(
        referenceWindow: const Duration(minutes: 12),
        smoothingAlpha: 1.0,
        minShiftDegrees: 0.5,
      );
      final t0 = DateTime.utc(2026, 11, 17, 10);

      tracker.update(
        twdDegrees: 80,
        twaSignedDegrees: 35,
        at: t0,
      );
      tracker.setReferenceNow();
      expect(tracker.hasPinnedReference, isTrue);

      final afterPin = tracker.reevaluate(twaSignedDegrees: 35);
      expect(afterPin, isNotNull);
      expect(afterPin!.deltaDegrees, closeTo(0, 1e-9));
      expect(afterPin.label, 'Lift +0°');

      final shifted = tracker.update(
        twdDegrees: 90,
        twaSignedDegrees: 35,
        at: t0.add(const Duration(seconds: 1)),
      );
      expect(shifted, isNotNull);
      expect(shifted!.isLift, isTrue);
      expect(shifted.deltaDegrees, closeTo(10, 0.5));
    });

    test('rolling mean tracks history inside the window', () {
      final tracker = WindShiftTracker(
        referenceWindow: const Duration(minutes: 12),
        smoothingAlpha: 1.0,
      );
      final t0 = DateTime.utc(2026, 11, 17, 10);

      for (var i = 0; i < 5; i++) {
        tracker.update(
          twdDegrees: 80,
          twaSignedDegrees: 30,
          at: t0.add(Duration(minutes: i)),
        );
      }
      final late = tracker.update(
        twdDegrees: 100,
        twaSignedDegrees: 30,
        at: t0.add(const Duration(minutes: 5)),
      );
      expect(late, isNotNull);
      expect(late!.isLift, isTrue);
      expect(late.deltaDegrees, greaterThan(5));
    });
  });
}
