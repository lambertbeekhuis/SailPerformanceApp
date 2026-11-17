import 'sailing_snapshot.dart';

/// Which instrument feeds the course/heading field on the dashboard.
///
/// Structured so a settings toggle can switch modes later without a rewrite.
enum CourseDisplayMode {
  /// Prefer true heading; fall back to COG when heading is missing.
  preferHeading,

  /// Always show heading (blank when missing).
  headingOnly,

  /// Always show COG (blank when missing).
  cogOnly,
}

/// Resolved course value for the dashboard.
class CourseDisplay {
  const CourseDisplay({
    required this.mode,
    required this.sourceLabel,
    this.value,
  });

  final CourseDisplayMode mode;

  /// Obvious label for the active choice: `Heading` or `COG`.
  final String sourceLabel;

  final TimedValue? value;

  /// Value used for display when not stale/null.
  double? get degrees => value?.value;
}

/// Pick heading vs COG according to [mode].
CourseDisplay resolveCourseDisplay(
  SailingSnapshot snapshot, {
  CourseDisplayMode mode = CourseDisplayMode.preferHeading,
}) {
  switch (mode) {
    case CourseDisplayMode.preferHeading:
      if (snapshot.headingTrue != null) {
        return CourseDisplay(
          mode: mode,
          sourceLabel: 'Heading',
          value: snapshot.headingTrue,
        );
      }
      return CourseDisplay(
        mode: mode,
        sourceLabel: 'COG',
        value: snapshot.cog,
      );
    case CourseDisplayMode.headingOnly:
      return CourseDisplay(
        mode: mode,
        sourceLabel: 'Heading',
        value: snapshot.headingTrue,
      );
    case CourseDisplayMode.cogOnly:
      return CourseDisplay(
        mode: mode,
        sourceLabel: 'COG',
        value: snapshot.cog,
      );
  }
}
