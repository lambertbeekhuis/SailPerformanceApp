import 'sailing_snapshot.dart';
import 'wind_math.dart';

class _TwdSample {
  const _TwdSample(this.at, this.twdDegrees);

  final DateTime at;
  final double twdDegrees;
}

/// Rolling TWD reference + smoothed TWD for lift/header (FR8).
///
/// Default reference window is 12 minutes (within the 10–15 min guidance).
/// [setReferenceNow] pins the current smoothed TWD until [clearPinnedReference].
class WindShiftTracker {
  WindShiftTracker({
    this.referenceWindow = const Duration(minutes: 12),
    this.smoothingAlpha = 0.25,
    this.minShiftDegrees = 0.5,
  });

  /// Rolling mean window for the automatic reference.
  final Duration referenceWindow;

  /// EMA alpha for smoothed TWD (0–1). Higher = more reactive.
  final double smoothingAlpha;

  /// Below this absolute delta, treat as flat (show Lift +0°).
  final double minShiftDegrees;

  final List<_TwdSample> _history = [];
  double? _smoothedTwd;
  double? _pinnedReference;
  LiftHeader? _latest;

  double? get smoothedTwd => _smoothedTwd;

  double? get referenceTwd {
    if (_pinnedReference != null) return _pinnedReference;
    return vectorMeanDegrees(_history.map((s) => s.twdDegrees));
  }

  bool get hasPinnedReference => _pinnedReference != null;

  LiftHeader? get latest => _latest;

  /// Pin the current smoothed TWD (or rolling mean) as the reference.
  void setReferenceNow() {
    _pinnedReference = _smoothedTwd ?? referenceTwd;
  }

  void clearPinnedReference() {
    _pinnedReference = null;
  }

  void reset() {
    _history.clear();
    _smoothedTwd = null;
    _pinnedReference = null;
    _latest = null;
  }

  /// Recompute lift/header against the current reference without a new sample.
  LiftHeader? reevaluate({required double twaSignedDegrees}) {
    final ref = referenceTwd;
    if (ref == null || _smoothedTwd == null) {
      _latest = null;
      return null;
    }
    return _finish(ref, twaSignedDegrees);
  }

  /// Ingest a freshly computed TWD + tack (signed TWA).
  LiftHeader? update({
    required double twdDegrees,
    required double twaSignedDegrees,
    required DateTime at,
  }) {
    final normalized = normalizeDegrees(twdDegrees);
    if (_smoothedTwd == null) {
      _smoothedTwd = normalized;
    } else {
      final delta = circularDeltaDegrees(_smoothedTwd!, normalized);
      _smoothedTwd = normalizeDegrees(_smoothedTwd! + smoothingAlpha * delta);
    }

    _history.add(_TwdSample(at, normalized));
    _prune(at);

    final ref = referenceTwd;
    if (ref == null || _smoothedTwd == null) {
      _latest = null;
      return null;
    }
    return _finish(ref, twaSignedDegrees);
  }

  LiftHeader? _finish(double ref, double twaSignedDegrees) {
    var result = evaluateLiftHeader(
      smoothedTwdDegrees: _smoothedTwd!,
      referenceTwdDegrees: ref,
      twaSignedDegrees: twaSignedDegrees,
    );
    if (result.deltaDegrees < minShiftDegrees) {
      result = LiftHeader(
        deltaDegrees: 0,
        isLift: true,
        onStarboard: result.onStarboard,
      );
    }
    _latest = result;
    return result;
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(referenceWindow);
    while (_history.isNotEmpty && _history.first.at.isBefore(cutoff)) {
      _history.removeAt(0);
    }
  }
}

/// Snapshot fields produced by the wind-shift pipeline.
class WindShiftState {
  const WindShiftState({
    this.twd,
    this.referenceTwd,
    this.liftHeader,
    this.pinnedReference = false,
  });

  final TimedValue? twd;
  final double? referenceTwd;
  final LiftHeader? liftHeader;
  final bool pinnedReference;
}
