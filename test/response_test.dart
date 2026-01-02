import 'package:dlms/dlms.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

void main() {
  group('DlmsValue', () {
    test('decodes basic types', () {
      // Unsigned (17) -> 100
      final reader = AxdrReader(Uint8List.fromList([17, 100]));
      final val = DlmsValue.decode(reader);
      expect(val.type, 17);
      expect(val.value, 100);
    });

    test('decodes recursive structure', () {
      // Structure (2) with 2 elements:
      // 1. VisibleString (10) "Hi" -> [10, 2, 72, 105]
      // 2. Boolean (3) true -> [3, 1]
      final bytes = Uint8List.fromList([2, 2, 10, 2, 72, 105, 3, 1]);
      final reader = AxdrReader(bytes);
      final val = DlmsValue.decode(reader);

      expect(val.type, 2);
      expect(val.value, isA<List>());
      final list = val.value as List<DlmsValue>;
      expect(list[0].value, 'Hi');
      expect(list[1].value, true);
    });
  });

  group('GetResponsePdu', () {
    test('parses GetResponseNormal with data', () {
      // C4 01 81 00 (choice data) [17 50] (Unsigned 80)
      final bytes = Uint8List.fromList([0xC4, 0x01, 0x81, 0x00, 17, 80]);
      final pdu = GetResponsePdu.fromBytes(bytes);

      expect(pdu.responseType, 1);
      expect(pdu.result?.value, 80);
      expect(pdu.resultError, isNull);
    });

    test('parses GetResponseNormal with error', () {
      // C4 01 81 01 (choice error) 05 (access-violation)
      final bytes = Uint8List.fromList([0xC4, 0x01, 0x81, 0x01, 0x05]);
      final pdu = GetResponsePdu.fromBytes(bytes);

      expect(pdu.resultError, 5);
      expect(pdu.result, isNull);
    });
  });
}
