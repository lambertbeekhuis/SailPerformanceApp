import 'dart:math' as math;

import 'wind_math.dart';

/// One instrument value with the time it was last updated.
class TimedValue {
  const TimedValue(this.value, this.updatedAt);

  final double value;
  final DateTime updatedAt;

  bool isStale(DateTime now, Duration timeout) =>
      now.difference(updatedAt) > timeout;
}

/// Default stale timeout for dashboard grey-out.
const Duration kDefaultStaleTimeout = Duration(seconds: 5);

/// Latest sailing values derived from the NMEA feed.
class SailingSnapshot {
  const SailingSnapshot({
    this.stw,
    this.sog,
    this.aws,
    this.awaDegreesFromBow,
    this.headingTrue,
    this.cog,
    this.tws,
    this.twaSigned,
    this.twd,
    this.liftHeaderLabel,
  });

  final TimedValue? stw;
  final TimedValue? sog;
  final TimedValue? aws;

  /// MWV angle 0–360 clockwise from the bow (instrument convention).
  final TimedValue? awaDegreesFromBow;
  final TimedValue? headingTrue;
  final TimedValue? cog;
  final TimedValue? tws;

  /// Signed TWA: positive = starboard, negative = port.
  final TimedValue? twaSigned;

  /// True wind direction (degrees true), water-referenced.
  final TimedValue? twd;

  /// Latest lift/header label, e.g. `Lift +3°` / `Header −2°`.
  final String? liftHeaderLabel;

  /// Preferred boat speed: STW when present, otherwise SOG.
  TimedValue? get preferredSpeed => stw ?? sog;

  /// Dashboard always labels this field "Speed" (value is STW, else SOG).
  String get preferredSpeedLabel => 'Speed';

  /// Signed AWA: positive = starboard, negative = port.
  double? get awaSigned {
    final awa = awaDegreesFromBow?.value;
    if (awa == null) return null;
    return signedWindAngle(awa);
  }

  SailingSnapshot copyWith({
    TimedValue? stw,
    TimedValue? sog,
    TimedValue? aws,
    TimedValue? awaDegreesFromBow,
    TimedValue? headingTrue,
    TimedValue? cog,
    TimedValue? tws,
    TimedValue? twaSigned,
    TimedValue? twd,
    String? liftHeaderLabel,
    bool clearLiftHeaderLabel = false,
  }) {
    return SailingSnapshot(
      stw: stw ?? this.stw,
      sog: sog ?? this.sog,
      aws: aws ?? this.aws,
      awaDegreesFromBow: awaDegreesFromBow ?? this.awaDegreesFromBow,
      headingTrue: headingTrue ?? this.headingTrue,
      cog: cog ?? this.cog,
      tws: tws ?? this.tws,
      twaSigned: twaSigned ?? this.twaSigned,
      twd: twd ?? this.twd,
      liftHeaderLabel: clearLiftHeaderLabel
          ? null
          : (liftHeaderLabel ?? this.liftHeaderLabel),
    );
  }

  /// Water-referenced true wind from apparent wind + STW (requirements §5).
  /// Also computes TWD when heading is available: `(heading + TWA) mod 360`.
  SailingSnapshot withComputedTrueWind({DateTime? at}) {
    final awsValue = aws?.value;
    final awa = awaSigned;
    final stwValue = stw?.value;
    if (awsValue == null || awa == null || stwValue == null) {
      return this;
    }
    final awaRad = awa * math.pi / 180.0;
    final awX = awsValue * math.cos(awaRad);
    final awY = awsValue * math.sin(awaRad);
    final twX = awX - stwValue;
    final twY = awY;
    final computedTws = math.sqrt(twX * twX + twY * twY);
    final computedTwa = math.atan2(twY, twX) * 180.0 / math.pi;
    final stamp = at ?? DateTime.now();

    TimedValue? computedTwd;
    final heading = headingTrue?.value;
    if (heading != null) {
      computedTwd = TimedValue(
        computeTwd(headingDegrees: heading, twaSignedDegrees: computedTwa),
        stamp,
      );
    }

    return copyWith(
      tws: TimedValue(computedTws, stamp),
      twaSigned: TimedValue(computedTwa, stamp),
      twd: computedTwd,
    );
  }
}

/// Convert MWV 0–360 (clockwise from bow) to signed angle
/// (positive starboard, negative port).
double signedWindAngle(double degreesFromBow) {
  var normalized = degreesFromBow % 360.0;
  if (normalized < 0) normalized += 360.0;
  if (normalized > 180.0) {
    return normalized - 360.0;
  }
  return normalized;
}
