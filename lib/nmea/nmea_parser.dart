import 'nmea_checksum.dart';
import 'sailing_snapshot.dart';

/// Incremental NMEA line parser that updates a [SailingSnapshot].
class NmeaParser {
  SailingSnapshot _snapshot = const SailingSnapshot();
  final StringBuffer _carry = StringBuffer();

  SailingSnapshot get snapshot => _snapshot;

  /// Feed raw bytes/text from a socket or file. Handles partial lines.
  void addChunk(String chunk, {DateTime? now}) {
    _carry.write(chunk);
    final text = _carry.toString();
    final parts = text.split(RegExp(r'\r?\n'));
    _carry
      ..clear()
      ..write(parts.isEmpty ? '' : parts.last);
    for (var i = 0; i < parts.length - 1; i++) {
      ingestLine(parts[i], now: now);
    }
  }

  /// Parse one complete line (with or without trailing newline).
  bool ingestLine(String rawLine, {DateTime? now}) {
    final line = rawLine.trim();
    if (line.isEmpty) return false;
    if (!nmeaChecksumValid(line)) return false;

    final star = line.lastIndexOf('*');
    final body = line.substring(1, star);
    final fields = body.split(',');
    if (fields.isEmpty) return false;

    final talkerAndType = fields.first;
    if (talkerAndType.length < 3) return false;
    final type = talkerAndType.substring(talkerAndType.length - 3).toUpperCase();
    final stamp = now ?? DateTime.now();

    switch (type) {
      case 'MWV':
        return _parseMwv(fields, stamp);
      case 'VHW':
        return _parseVhw(fields, stamp);
      case 'VTG':
        return _parseVtg(fields, stamp);
      case 'RMC':
        return _parseRmc(fields, stamp);
      case 'HDT':
        return _parseHdt(fields, stamp);
      case 'HDG':
        return _parseHdg(fields, stamp);
      default:
        return false;
    }
  }

  void reset() {
    _snapshot = const SailingSnapshot();
    _carry.clear();
  }

  bool _parseMwv(List<String> f, DateTime stamp) {
    // MWV,x.x,a,x.x,a,A
    if (f.length < 6) return false;
    if (f[5].toUpperCase() != 'A') return false;
    final angle = double.tryParse(f[1]);
    final ref = f[2].toUpperCase();
    final speed = double.tryParse(f[3]);
    final unit = f[4].toUpperCase();
    if (angle == null || speed == null) return false;
    // Only relative (apparent) for dashboard AWS/AWA.
    if (ref != 'R') return false;
    final knots = _toKnots(speed, unit);
    if (knots == null) return false;
    _snapshot = _snapshot
        .copyWith(
          awaDegreesFromBow: TimedValue(angle, stamp),
          aws: TimedValue(knots, stamp),
        )
        .withComputedTrueWind(at: stamp);
    return true;
  }

  bool _parseVhw(List<String> f, DateTime stamp) {
    // VHW,headingT,T,headingM,M,stwN,N,stwK,K
    if (f.length < 6) return false;
    final heading = double.tryParse(f[1]);
    final stwN = f.length > 5 ? double.tryParse(f[5]) : null;
    TimedValue? stw;
    if (stwN != null) {
      stw = TimedValue(stwN, stamp);
    } else if (f.length > 7) {
      final stwK = double.tryParse(f[7]);
      if (stwK != null) {
        stw = TimedValue(stwK / 1.852, stamp);
      }
    }
    _snapshot = _snapshot
        .copyWith(
          headingTrue: heading != null ? TimedValue(heading, stamp) : null,
          stw: stw,
        )
        .withComputedTrueWind(at: stamp);
    return stw != null || heading != null;
  }

  bool _parseVtg(List<String> f, DateTime stamp) {
    // VTG,cogT,T,cogM,M,sogN,N,sogK,K
    if (f.length < 6) return false;
    final cog = double.tryParse(f[1]);
    final sogN = double.tryParse(f[5]);
    TimedValue? sog;
    if (sogN != null) {
      sog = TimedValue(sogN, stamp);
    } else if (f.length > 7) {
      final sogK = double.tryParse(f[7]);
      if (sogK != null) sog = TimedValue(sogK / 1.852, stamp);
    }
    _snapshot = _snapshot.copyWith(
      cog: cog != null ? TimedValue(cog, stamp) : null,
      sog: sog,
    );
    return sog != null || cog != null;
  }

  bool _parseRmc(List<String> f, DateTime stamp) {
    // RMC,time,status,lat,N,lon,E,sog,cog,date,...
    if (f.length < 9) return false;
    if (f[2].toUpperCase() != 'A') return false;
    final sog = double.tryParse(f[7]);
    final cog = double.tryParse(f[8]);
    _snapshot = _snapshot.copyWith(
      sog: sog != null ? TimedValue(sog, stamp) : null,
      cog: cog != null ? TimedValue(cog, stamp) : null,
    );
    return sog != null || cog != null;
  }

  bool _parseHdt(List<String> f, DateTime stamp) {
    if (f.length < 2) return false;
    final heading = double.tryParse(f[1]);
    if (heading == null) return false;
    _snapshot = _snapshot
        .copyWith(headingTrue: TimedValue(heading, stamp))
        .withComputedTrueWind(at: stamp);
    return true;
  }

  bool _parseHdg(List<String> f, DateTime stamp) {
    if (f.length < 2) return false;
    final heading = double.tryParse(f[1]);
    if (heading == null) return false;
    _snapshot = _snapshot
        .copyWith(headingTrue: TimedValue(heading, stamp))
        .withComputedTrueWind(at: stamp);
    return true;
  }

  double? _toKnots(double speed, String unit) {
    switch (unit) {
      case 'N':
        return speed;
      case 'K':
        return speed / 1.852;
      case 'M':
        return speed * 1.94384; // m/s → kn
      default:
        return null;
    }
  }
}
