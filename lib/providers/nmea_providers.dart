import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/file_nmea_source.dart';
import '../data/live_tcp_nmea_source.dart';
import '../data/nmea_data_source.dart';
import '../nmea/nmea_parser.dart';
import '../nmea/sailing_snapshot.dart';

/// Debug/settings toggle: File (replay) vs Live (TCP).
final nmeaSourceKindProvider =
    StateProvider<NmeaSourceKind>((ref) => NmeaSourceKind.file);

/// Optional live gateway host (empty = not configured).
final liveHostProvider = StateProvider<String>((ref) => '');

/// Optional live gateway port (typical 10110 or 2000).
final livePortProvider = StateProvider<int>((ref) => 10110);

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

class SailingFeedController extends StateNotifier<SailingSnapshot> {
  SailingFeedController(this._ref) : super(const SailingSnapshot());

  final Ref _ref;
  final NmeaParser _parser = NmeaParser();
  NmeaDataSource? _source;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<NmeaSourceStatus>? _statusSub;

  Future<void> restart() async {
    await _tearDownSource();
    if (!mounted) return;
    _parser.reset();
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
      if (ok) {
        state = _parser.snapshot;
      }
    });

    await source.start();
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
