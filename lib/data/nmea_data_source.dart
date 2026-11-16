import 'dart:async';

/// How the app obtains raw NMEA text.
enum NmeaSourceKind {
  /// Bundled / asset log replay (default in debug).
  file,

  /// Live TCP connection to a Wi‑Fi NMEA gateway.
  live,
}

extension NmeaSourceKindLabel on NmeaSourceKind {
  String get label {
    switch (this) {
      case NmeaSourceKind.file:
        return 'File';
      case NmeaSourceKind.live:
        return 'Live';
    }
  }
}

/// Connection / feed status shown in the UI.
enum NmeaConnectionState {
  idle,
  connecting,
  streaming,
  disconnected,
  error,
}

/// Status snapshot for the active data source.
class NmeaSourceStatus {
  const NmeaSourceStatus({
    required this.kind,
    required this.state,
    this.message,
    this.host,
    this.port,
  });

  final NmeaSourceKind kind;
  final NmeaConnectionState state;
  final String? message;
  final String? host;
  final int? port;

  String get summary {
    switch (state) {
      case NmeaConnectionState.idle:
        return 'Idle';
      case NmeaConnectionState.connecting:
        return 'Connecting…';
      case NmeaConnectionState.streaming:
        return kind == NmeaSourceKind.file ? 'Replaying file' : 'Connected';
      case NmeaConnectionState.disconnected:
        return message ?? 'Not connected';
      case NmeaConnectionState.error:
        return message ?? 'Error';
    }
  }
}

/// Abstraction over live gateway and file/replay NMEA inputs.
///
/// Both implementations feed the same parser pipeline via [lines].
abstract class NmeaDataSource {
  NmeaSourceKind get kind;

  Stream<String> get lines;

  Stream<NmeaSourceStatus> get status;

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}
