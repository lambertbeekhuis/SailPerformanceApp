import 'package:flutter_test/flutter_test.dart';
import 'package:sail_performance/nmea/nmea_checksum.dart';
import 'package:sail_performance/nmea/nmea_parser.dart';
import 'package:sail_performance/nmea/sailing_snapshot.dart';

void main() {
  group('nmeaChecksum', () {
    test('matches known MWV sentence', () {
      const body = 'IIMWV,32.0,R,11.5,N,A';
      expect(nmeaChecksum(body), '39');
      expect(nmeaChecksumValid(nmeaSentence(body)), isTrue);
    });

    test('rejects bad checksum', () {
      expect(nmeaChecksumValid(r'$IIMWV,99.0,R,1.0,N,A*00'), isFalse);
    });
  });

  group('signedWindAngle', () {
    test('starboard stays positive', () {
      expect(signedWindAngle(32), closeTo(32, 1e-9));
    });

    test('port wraps to negative', () {
      expect(signedWindAngle(330), closeTo(-30, 1e-9));
    });
  });

  group('NmeaParser', () {
    late NmeaParser parser;
    final stamp = DateTime.utc(2026, 11, 16, 12);

    setUp(() {
      parser = NmeaParser();
    });

    test('parses MWV + VHW and computes TWS/TWA', () {
      expect(
        parser.ingestLine(nmeaSentence('IIMWV,32.0,R,11.5,N,A'), now: stamp),
        isTrue,
      );
      expect(
        parser.ingestLine(
          nmeaSentence('IIVHW,45.0,T,45.0,M,6.00,N,11.11,K'),
          now: stamp,
        ),
        isTrue,
      );

      final snap = parser.snapshot;
      expect(snap.aws?.value, closeTo(11.5, 1e-9));
      expect(snap.awaSigned, closeTo(32.0, 1e-9));
      expect(snap.stw?.value, closeTo(6.0, 1e-9));
      expect(snap.preferredSpeedLabel, 'STW');
      expect(snap.tws, isNotNull);
      expect(snap.twaSigned, isNotNull);
      expect(snap.tws!.value, greaterThan(0));
    });

    test('falls back to SOG from VTG when STW missing', () {
      expect(
        parser.ingestLine(
          nmeaSentence('IIVTG,45.0,T,45.0,M,5.82,N,10.78,K'),
          now: stamp,
        ),
        isTrue,
      );
      expect(parser.snapshot.sog?.value, closeTo(5.82, 1e-9));
      expect(parser.snapshot.preferredSpeedLabel, 'SOG');
      expect(parser.snapshot.preferredSpeed?.value, closeTo(5.82, 1e-9));
    });

    test('ignores garbage and bad checksums', () {
      expect(parser.ingestLine('GARBAGE not nmea'), isFalse);
      expect(parser.ingestLine(r'$IIMWV,99.0,R,1.0,N,A*00'), isFalse);
      expect(parser.snapshot.aws, isNull);
    });

    test('handles partial chunks across addChunk calls', () {
      parser.addChunk(r'$IIMWV,30.0,R,10.0,N,', now: stamp);
      expect(parser.snapshot.aws, isNull);
      final rest = nmeaSentence('IIMWV,30.0,R,10.0,N,A').substring(
        r'$IIMWV,30.0,R,10.0,N,'.length,
      );
      parser.addChunk('$rest\n', now: stamp);
      expect(parser.snapshot.aws?.value, closeTo(10.0, 1e-9));
    });

    test('feeds a multi-line sample like the file source', () {
      const sample = '''
\$IIMWV,32.0,R,11.5,N,A*39
\$IIVHW,45.0,T,45.0,M,6.00,N,11.11,K*63
\$IIVTG,45.0,T,45.0,M,5.82,N,10.78,K*68
''';
      for (final line in sample.split('\n')) {
        if (line.trim().isEmpty) continue;
        parser.ingestLine(line, now: stamp);
      }
      expect(parser.snapshot.stw?.value, closeTo(6.0, 1e-9));
      expect(parser.snapshot.sog?.value, closeTo(5.82, 1e-9));
      expect(parser.snapshot.aws?.value, closeTo(11.5, 1e-9));
    });
  });
}
