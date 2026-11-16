import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;

import 'nmea_data_source.dart';

/// Replays a bundled NMEA log through the same line stream as live TCP.
class FileNmeaSource implements NmeaDataSource {
  FileNmeaSource({
    this.assetPath = 'assets/nmea/sample_sailing.nmea',
    this.interval = const Duration(milliseconds: 200),
    this.loop = true,
  });

  final String assetPath;
  final Duration interval;
  final bool loop;

  final _lineController = StreamController<String>.broadcast();
  final _statusController = StreamController<NmeaSourceStatus>.broadcast();

  Timer? _timer;
  List<String> _lines = const [];
  int _index = 0;
  bool _started = false;

  @override
  NmeaSourceKind get kind => NmeaSourceKind.file;

  @override
  Stream<String> get lines => _lineController.stream;

  @override
  Stream<NmeaSourceStatus> get status => _statusController.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _emit(
      NmeaConnectionState.connecting,
      message: 'Loading $assetPath',
    );
    final raw = await rootBundle.loadString(assetPath);
    _lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    _index = 0;
    _started = true;
    _emit(
      NmeaConnectionState.streaming,
      message: 'Replaying ${_lines.length} lines',
    );
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    if (_lines.isEmpty) {
      _emit(
        NmeaConnectionState.disconnected,
        message: 'Sample log is empty',
      );
      _timer?.cancel();
      return;
    }
    _lineController.add(_lines[_index]);
    _index++;
    if (_index >= _lines.length) {
      if (loop) {
        _index = 0;
      } else {
        _timer?.cancel();
        _started = false;
        _emit(
          NmeaConnectionState.disconnected,
          message: 'Replay finished',
        );
      }
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _emit(
      NmeaConnectionState.disconnected,
      message: 'Replay stopped',
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _lineController.close();
    await _statusController.close();
  }

  void _emit(NmeaConnectionState state, {String? message}) {
    if (_statusController.isClosed) return;
    _statusController.add(
      NmeaSourceStatus(
        kind: kind,
        state: state,
        message: message,
      ),
    );
  }
}
