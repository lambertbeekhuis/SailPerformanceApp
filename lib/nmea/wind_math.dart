import 'dart:math' as math;

/// Normalize degrees into [0, 360).
double normalizeDegrees(double degrees) {
  var n = degrees % 360.0;
  if (n < 0) n += 360.0;
  // Fold floating-point 360 back to 0 (e.g. vector mean near north).
  if (n >= 360.0 - 1e-9) return 0.0;
  return n;
}

/// Shortest signed circular delta from [fromDegrees] to [toDegrees]
/// in (−180, 180]: positive = clockwise.
double circularDeltaDegrees(double fromDegrees, double toDegrees) {
  var delta = normalizeDegrees(toDegrees) - normalizeDegrees(fromDegrees);
  if (delta > 180.0) delta -= 360.0;
  if (delta <= -180.0) delta += 360.0;
  return delta;
}

/// Vector (circular) mean of compass angles in degrees.
/// Returns null when [degrees] is empty.
double? vectorMeanDegrees(Iterable<double> degrees) {
  var sumSin = 0.0;
  var sumCos = 0.0;
  var count = 0;
  for (final d in degrees) {
    final rad = d * math.pi / 180.0;
    sumSin += math.sin(rad);
    sumCos += math.cos(rad);
    count++;
  }
  if (count == 0) return null;
  if (sumSin == 0.0 && sumCos == 0.0) return null;
  return normalizeDegrees(math.atan2(sumSin, sumCos) * 180.0 / math.pi);
}

/// Water-referenced TWD from heading + signed TWA (requirements §5).
/// `TWD = (heading + TWA) mod 360`.
double computeTwd({
  required double headingDegrees,
  required double twaSignedDegrees,
}) {
  return normalizeDegrees(headingDegrees + twaSignedDegrees);
}

/// Lift / header relative to a TWD reference, tack-aware (requirements §5 / FR8).
///
/// On starboard (signed TWA ≥ 0): clockwise TWD change = lift.
/// On port (signed TWA < 0): counter-clockwise TWD change = lift.
class LiftHeader {
  const LiftHeader({
    required this.deltaDegrees,
    required this.isLift,
    required this.onStarboard,
  });

  /// Absolute shift magnitude in degrees (≥ 0).
  final double deltaDegrees;

  /// True → lift; false → header. Zero delta is treated as lift +0°.
  final bool isLift;

  final bool onStarboard;

  /// Display like `Lift +3°` / `Header −3°`.
  String get label {
    final x = deltaDegrees.round().clamp(0, 999);
    if (isLift) {
      return 'Lift +$x°';
    }
    return 'Header −$x°';
  }
}

LiftHeader evaluateLiftHeader({
  required double smoothedTwdDegrees,
  required double referenceTwdDegrees,
  required double twaSignedDegrees,
}) {
  final clockwise =
      circularDeltaDegrees(referenceTwdDegrees, smoothedTwdDegrees);
  final onStarboard = twaSignedDegrees >= 0;
  // Starboard: clockwise = lift; port: reverse.
  final isLift = onStarboard ? clockwise >= 0 : clockwise <= 0;
  return LiftHeader(
    deltaDegrees: clockwise.abs(),
    isLift: isLift,
    onStarboard: onStarboard,
  );
}
