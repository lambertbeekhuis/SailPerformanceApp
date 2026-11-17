import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/file_nmea_source.dart';
import '../data/live_tcp_nmea_source.dart';
import '../data/nmea_data_source.dart';
import '../nmea/course_display.dart';
import '../nmea/nmea_parser.dart';
import '../nmea/sailing_snapshot.dart';
import '../nmea/wind_shift_tracker.dart';

/// Debug/settings toggle: File (replay) vs Live (TCP).
final nmeaSourceKindProvider =
    StateProvider<NmeaSourceKind>((ref) => NmeaSourceKind.file);

/// Optional live gateway host (empty = not configured).
final liveHostProvider = StateProvider<String>((ref) => '');

/// Optional live gateway port (typical 10110 or 2000).
final livePortProvider = StateProvider<int>((ref) => 10110);

/// Heading vs COG display preference (settings hook for later).
final courseDisplayModeProvider =
    StateProvider<CourseDisplayMode>((ref) => CourseDisplayMode.preferHeading);

final nmeaSourceStatusProvider = StateProvider<NmeaSourceStatus>((ref) {
  return const NmeaSourceStatus(
    kind: NmeaSourceKind.file,
    state: NmeaConnectionState.idle,
  );
});

final sailingSnapshotProvider =
    StateNotifierProvider<SailingFeedController, SailingSnapshot>((ref) {
  final controller = SailingFeedController(ref);
  // Kick off the default file source after the first frame of listeners.
  scheduleMicrotask(controller.restart);
  return controller;
});

/// Resolved course field for the dashboard (Heading or COG).
final courseDisplayProvider = Provider<CourseDisplay>((ref) {
  final snapshot = ref.watch(sailingSnapshotProvider);
  final mode = ref.watch(courseDisplayModeProvider);
  return resolveCourseDisplay(snapshot, mode: mode);
});

/// Whether the wind-shift reference is currently pinned ("set reference now").
final windReferencePinnedProvider = StateProvider<bool>((ref) => false);

class SailingFeedController extends StateNotifier<SailingSnapshot> {
  SailingFeedController(this._ref) : super(const SailingSnapshot());

  final Ref _ref;
  final NmeaParser _parser = NmeaParser();
  final WindShiftTracker _windShift = WindShiftTracker();
  NmeaDataSource? _source;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<NmeaSourceStatus>? _statusSub;

  /// Pin current smoothed TWD as the lift/header reference (FR8).
  void setWindReferenceNow() {
    _windShift.setReferenceNow();
    _ref.read(windReferencePinnedProvider.notifier).state =
        _windShift.hasPinnedReference;
    final twa = state.twaSigned?.value;
    if (twa == null) return;
    final result = _windShift.reevaluate(twaSignedDegrees: twa);
    state = state.copyWith(
      liftHeaderLabel: result?.label,
      clearLiftHeaderLabel: result == null,
    );
  }

  Future<void> restart() async {
    await _tearDownSource();
    if (!mounted) return;
    _parser.reset();
    _windShift.reset();
    _ref.read(windReferencePinnedProvider.notifier).state = false;
    state = const SailingSnapshot();

    final kind = _ref.read(nmeaSourceKindProvider);
    final NmeaDataSource source;
    switch (kind) {
      case NmeaSourceKind.file:
        source = FileNmeaSource();
      case NmeaSourceKind.live:
        source = LiveTcpNmeaSource(
          host: _ref.read(liveHostProvider),
          port: _ref.read(livePortProvider),
        );
    }
    _source = source;

    _statusSub = source.status.listen((status) {
      if (!mounted) return;
      _ref.read(nmeaSourceStatusProvider.notifier).state = status;
    });
    _lineSub = source.lines.listen((line) {
      if (!mounted) return;
      final ok = _parser.ingestLine(line);
      if (!ok) return;
      state = _applyWindShift(_parser.snapshot);
    });

    await source.start();
  }

  SailingSnapshot _applyWindShift(SailingSnapshot snap) {
    final twd = snap.twd?.value;
    final twa = snap.twaSigned?.value;
    final at = snap.twd?.updatedAt;
    if (twd == null || twa == null || at == null) {
      return snap.copyWith(clearLiftHeaderLabel: true);
    }
    final result = _windShift.update(
      twdDegrees: twd,
      twaSignedDegrees: twa,
      at: at,
    );
    final smoothed = _windShift.smoothedTwd;
    return snap.copyWith(
      twd: smoothed != null ? TimedValue(smoothed, at) : snap.twd,
      liftHeaderLabel: result?.label,
      clearLiftHeaderLabel: result == null,
    );
  }

  Future<void> setKind(NmeaSourceKind kind) async {
    if (_ref.read(nmeaSourceKindProvider) == kind) return;
    _ref.read(nmeaSourceKindProvider.notifier).state = kind;
    await restart();
  }

  Future<void> _tearDownSource() async {
    final source = _source;
    _source = null;
    final lineSub = _lineSub;
    final statusSub = _statusSub;
    _lineSub = null;
    _statusSub = null;
    await lineSub?.cancel();
    await statusSub?.cancel();
    await source?.dispose();
  }

  @override
  void dispose() {
    // Drop the active source synchronously enough that FileNmeaSource cancels
    // its Timer before widget tests verify no pending timers.
    final source = _source;
    _source = null;
    _lineSub?.cancel();
    _statusSub?.cancel();
    _lineSub = null;
    _statusSub = null;
    if (source != null) {
      unawaited(source.dispose());
    }
    super.dispose();
  }
}
