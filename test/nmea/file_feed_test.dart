import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sail_performance/nmea/nmea_parser.dart';

void main() {
  test('bundled sample NMEA feeds parser with speed and wind', () async {
    final file = File('assets/nmea/sample_sailing.nmea');
    expect(file.existsSync(), isTrue, reason: 'sample log must ship in assets');

    final parser = NmeaParser();
    final stamp = DateTime.utc(2026, 11, 16, 12);
    var accepted = 0;
    for (final line in await file.readAsLines()) {
      if (parser.ingestLine(line, now: stamp)) {
        accepted++;
      }
    }

    expect(accepted, greaterThan(10));
    expect(parser.snapshot.stw, isNotNull);
    expect(parser.snapshot.aws, isNotNull);
    expect(parser.snapshot.awaDegreesFromBow, isNotNull);
    expect(parser.snapshot.preferredSpeedLabel, 'STW');
    expect(parser.snapshot.tws, isNotNull);
  });
}
