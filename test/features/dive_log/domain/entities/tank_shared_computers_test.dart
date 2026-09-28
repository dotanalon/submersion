import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';

void main() {
  group('decodeSharedComputerIds', () {
    test('null and blank text read as no sharers', () {
      expect(decodeSharedComputerIds(null), isEmpty);
      expect(decodeSharedComputerIds(''), isEmpty);
      expect(decodeSharedComputerIds('   '), isEmpty);
    });

    test('reads a JSON array of computer ids', () {
      expect(decodeSharedComputerIds('["garmin","ocean"]'), [
        'garmin',
        'ocean',
      ]);
    });

    test('text that is not JSON reads as no sharers', () {
      expect(decodeSharedComputerIds('garmin'), isEmpty);
    });

    test('JSON that is not an array reads as no sharers', () {
      expect(decodeSharedComputerIds('{"id":"garmin"}'), isEmpty);
    });

    test('non-string entries are skipped', () {
      expect(decodeSharedComputerIds('["garmin",7,null]'), ['garmin']);
    });
  });

  group('encodeSharedComputerIds', () {
    test('an empty list is stored as null', () {
      expect(encodeSharedComputerIds(const []), isNull);
    });

    test('duplicates are stored once and the result round-trips', () {
      final encoded = encodeSharedComputerIds(['garmin', 'ocean', 'garmin']);
      expect(decodeSharedComputerIds(encoded), ['garmin', 'ocean']);
    });
  });
}
