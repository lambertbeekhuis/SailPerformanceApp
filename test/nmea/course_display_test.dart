import 'package:flutter_test/flutter_test.dart';
import 'package:sail_performance/nmea/course_display.dart';
import 'package:sail_performance/nmea/sailing_snapshot.dart';

void main() {
  final stamp = DateTime.utc(2026, 11, 17, 12);

  group('resolveCourseDisplay', () {
    test('preferHeading uses heading when present', () {
      final snap = SailingSnapshot(
        headingTrue: TimedValue(45, stamp),
        cog: TimedValue(50, stamp),
      );
      final course = resolveCourseDisplay(snap);
      expect(course.sourceLabel, 'Heading');
      expect(course.degrees, closeTo(45, 1e-9));
    });

    test('preferHeading falls back to COG', () {
      final snap = SailingSnapshot(
        cog: TimedValue(50, stamp),
      );
      final course = resolveCourseDisplay(snap);
      expect(course.sourceLabel, 'COG');
      expect(course.degrees, closeTo(50, 1e-9));
    });

    test('cogOnly ignores heading', () {
      final snap = SailingSnapshot(
        headingTrue: TimedValue(45, stamp),
        cog: TimedValue(50, stamp),
      );
      final course = resolveCourseDisplay(
        snap,
        mode: CourseDisplayMode.cogOnly,
      );
      expect(course.sourceLabel, 'COG');
      expect(course.degrees, closeTo(50, 1e-9));
    });
  });
}
