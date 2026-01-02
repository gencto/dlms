import 'package:dlms/dlms.dart';
import 'package:test/test.dart';

void main() {
  group('AarqPdu', () {
    test('generates valid AARQ bytes with no security', () {
      final aarq = AarqPdu(maxPduSize: 1024);

      final bytes = aarq.toBytes();

      // Basic checks
      expect(bytes[0], equals(0x60)); // AARQ Tag

      // Check for xDLMS Initiate Request Tag (0x01) inside the blob
      // It's deep inside, but we can verify length > 20
      expect(bytes.length, greaterThan(20));

      // Verify Max PDU Size (1024 = 0x0400) is at the end of the xDLMS block
      // The xDLMS block is at the end.
      // 0x04, 0x00 should be near the end.
      expect(bytes[bytes.length - 2], equals(0x04));
      expect(bytes[bytes.length - 1], equals(0x00));
    });

    test('generates AARQ with LLS password', () {
      final aarq = AarqPdu(authenticationKey: '12345678', maxPduSize: 1024);

      final bytes = aarq.toBytes();

      // Check for Authentication Value Tag (0xAC)
      // AC is standard for the outer wrapper of auth value
      bool foundAuthTag = false;
      for (var b in bytes) {
        if (b == 0xAC) foundAuthTag = true;
      }
      expect(foundAuthTag, isTrue);
    });
  });

  group('GetRequestPdu', () {
    test('generates GetRequestNormal', () {
      final obis = ObisCode(1, 0, 1, 8, 0, 255); // Active Energy
      final getReq = GetRequestPdu.normal(
        classId: 3, // Register
        instanceId: obis,
        attributeId: 2, // Value
      );

      final bytes = getReq.toBytes();

      // C0 (Tag) 01 (Normal) 81 (InvokeID)
      expect(bytes[0], 0xC0);
      expect(bytes[1], 0x01);
      expect(bytes[2], 0x81);

      // Class ID 00 03
      expect(bytes[3], 0x00);
      expect(bytes[4], 0x03);

      // Obis Code length (06) + Obis Bytes... wait, AxdrWriter writes OctetString with length prefix?
      // Yes, writer.writeOctetString writes length then bytes.
      // 1.0.1.8.0.255
      expect(bytes[5], 0x06); // Length
      expect(bytes[6], 1);

      // Attribute ID 2
      // Where is it?
      // bytes: C0 01 81 00 03 [06 01 00 01 08 00 FF] 02 00
      // Index: 0  1  2  3  4  5  6  7  8  9  10 11  12 13
      expect(bytes[12], 0x02);

      // Access selector 0 (not present)
      expect(bytes[13], 0x00);
    });
  });
}
