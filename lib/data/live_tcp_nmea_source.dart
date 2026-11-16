import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'nmea_data_source.dart';

/// Minimal TCP client for a Wi‑Fi NMEA gateway.
///
/// When [host] is empty, stays in a clear “not connected / configure later”
/// state without attempting a socket.
class LiveTcpNmeaSource implements NmeaDataSource {
  LiveTcpNmeaSource({
    this.host = '',
    this.port = 10110,
  });

  String host;
  int port;

  final _lineController = StreamController<String>.broadcast();
  final _statusController = StreamController<NmeaSourceStatus>.broadcast();

  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  final StringBuffer _buffer = StringBuffer();
  bool _started = false;

  @override
  NmeaSourceKind get kind => NmeaSourceKind.live;

  @override
  Stream<String> get lines => _lineController.stream;

  @override
  Stream<NmeaSourceStatus> get status => _statusController.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final trimmedHost = host.trim();
    if (trimmedHost.isEmpty) {
      _emit(
        NmeaConnectionState.disconnected,
        message: 'Not connected — configure host:port later',
      );
      return;
    }

    _emit(
      NmeaConnectionState.connecting,
      message: 'Connecting to $trimmedHost:$port',
    );

    try {
      final socket = await Socket.connect(
        trimmedHost,
        port,
        timeout: const Duration(seconds: 5),
      );
      _socket = socket;
      _emit(
        NmeaConnectionState.streaming,
        message: 'Connected to $trimmedHost:$port',
      );
      _subscription = socket.listen(
        _onData,
        onError: (Object error, StackTrace _) {
          _emit(
            NmeaConnectionState.error,
            message: 'Socket error: $error',
          );
          unawaited(stop());
        },
        onDone: () {
          _emit(
            NmeaConnectionState.disconnected,
            message: 'Gateway closed the connection',
          );
          unawaited(stop());
        },
        cancelOnError: true,
      );
    } on Object catch (error) {
      _emit(
        NmeaConnectionState.error,
        message: 'Could not connect: $error',
      );
      _started = false;
    }
  }

  void _onData(List<int> data) {
    _buffer.write(utf8.decode(data, allowMalformed: true));
    final text = _buffer.toString();
    final parts = text.split(RegExp(r'\r?\n'));
    _buffer
      ..clear()
      ..write(parts.isEmpty ? '' : parts.last);
    for (var i = 0; i < parts.length - 1; i++) {
      final line = parts[i].trim();
      if (line.isNotEmpty) {
        _lineController.add(line);
      }
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    _buffer.clear();
    _started = false;
    if (!_statusController.isClosed) {
      // Avoid overwriting a more specific error/disconnected message if one
      // was already emitted by the caller path.
      _emit(
        NmeaConnectionState.disconnected,
        message: host.trim().isEmpty
            ? 'Not connected — configure host:port later'
            : 'Disconnected',
      );
    }
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
        host: host.trim().isEmpty ? null : host.trim(),
        port: port,
      ),
    );
  }
}
