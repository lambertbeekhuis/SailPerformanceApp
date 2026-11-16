import 'dart:math' as math;

/// One instrument value with the time it was last updated.
class TimedValue {
  const TimedValue(this.value, this.updatedAt);

  final double value;
  final DateTime updatedAt;

  bool isStale(DateTime now, Duration timeout) =>
      now.difference(updatedAt) > timeout;
}

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

  /// Preferred boat speed: STW when present, otherwise SOG.
  TimedValue? get preferredSpeed => stw ?? sog;

  String get preferredSpeedLabel {
    if (stw != null) return 'STW';
    if (sog != null) return 'SOG';
    return 'Speed';
  }

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
    );
  }

  /// Water-referenced true wind from apparent wind + STW (requirements §5).
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
    return copyWith(
      tws: TimedValue(computedTws, stamp),
      twaSigned: TimedValue(computedTwa, stamp),
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
