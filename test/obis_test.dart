import 'package:dlms/src/cosem/obis_code.dart';
import 'package:test/test.dart';

void main() {
  group('ObisCode', () {
    test('parses from string', () {
      final obis = ObisCode.fromString('1.0.1.8.0.255');
      expect(obis.a, 1);
      expect(obis.d, 8);
      expect(obis.f, 255);
    });

    test('converts to bytes', () {
      final obis = ObisCode(1, 0, 1, 8, 0, 255);
      expect(obis.toBytes(), equals([1, 0, 1, 8, 0, 255]));
    });

    test('equality works', () {
      final obis1 = ObisCode.fromString('1.1.1.1.1.1');
      final obis2 = ObisCode(1, 1, 1, 1, 1, 1);
      expect(obis1, equals(obis2));
      expect(obis1.hashCode, equals(obis2.hashCode));
    });

    test('toString formatting', () {
      final obis = ObisCode(1, 2, 3, 4, 5, 6);
      expect(obis.toString(), '1.2.3.4.5.6');
    });
  });
}
