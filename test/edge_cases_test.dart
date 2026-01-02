import 'package:dlms/dlms.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

void main() {
  group('Edge Cases', () {
    test('AxdrReader throws on empty buffer', () {
      final reader = AxdrReader(Uint8List(0));
      expect(() => reader.readUint8(), throwsRangeError);
    });

    test('AxdrReader throws on partial read', () {
      final reader = AxdrReader(Uint8List.fromList([0x01]));
      expect(() => reader.readUint16(), throwsRangeError);
    });

    test('ObisCode handles invalid strings', () {
      expect(() => ObisCode.fromString('1.2.3'), throwsFormatException);
      expect(() => ObisCode.fromString('1.2.3.4.5.a'), throwsFormatException);
    });

    test('ObisCode handles invalid byte length', () {
      expect(() => ObisCode.fromBytes([1, 2, 3]), throwsFormatException);
    });

    test('AarePdu handles garbage data', () {
      expect(
        () => AarePdu(Uint8List.fromList([0x00, 0x01])),
        throwsFormatException,
      );
    });

    test('AarePdu handles truncated data', () {
      // 61 05 A2 03 ... missing bytes
      final truncated = Uint8List.fromList([0x61, 0x05, 0xA2, 0x03]);
      expect(
        () => AarePdu(truncated),
        throwsA(anyOf(isA<RangeError>(), isA<FormatException>())),
      );
    });
  });
}
