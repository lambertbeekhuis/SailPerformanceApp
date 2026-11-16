/// NMEA 0183 checksum helpers (XOR of bytes between `$` and `*`).
library;

/// Returns the two-character uppercase hex checksum for [body]
/// (the part between `$` and `*`, excluding both).
String nmeaChecksum(String body) {
  var value = 0;
  for (final codeUnit in body.codeUnits) {
    value ^= codeUnit;
  }
  return value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// Validates a full NMEA sentence that includes `$…*XX`.
/// Returns `true` when the checksum matches.
bool nmeaChecksumValid(String sentence) {
  final trimmed = sentence.trim();
  if (!trimmed.startsWith(r'$') || !trimmed.contains('*')) {
    return false;
  }
  final star = trimmed.lastIndexOf('*');
  if (star < 1 || star + 3 > trimmed.length) {
    return false;
  }
  final body = trimmed.substring(1, star);
  final expected = trimmed.substring(star + 1, star + 3).toUpperCase();
  return nmeaChecksum(body) == expected;
}

/// Builds a full sentence `$body*XX` with a correct checksum.
String nmeaSentence(String body) => '\$$body*${nmeaChecksum(body)}';
