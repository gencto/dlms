import 'package:dlms/src/encoding/axdr_reader.dart';
import 'package:dlms/src/encoding/axdr_writer.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

void main() {
  group('AxdrWriter', () {
    test('writes boolean values correctly', () {
      final writer = AxdrWriter();
      writer.writeBoolean(true);
      writer.writeBoolean(false);
      expect(writer.toBytes(), equals([0x01, 0x00]));
    });

    test('writes integers correctly', () {
      final writer = AxdrWriter();
      writer.writeUint8(255);
      writer.writeUint16(65535);
      expect(writer.toBytes(), equals([0xFF, 0xFF, 0xFF]));
    });

    test('writes octet string with correct length prefix', () {
      final writer = AxdrWriter();
      writer.writeOctetString([0xCA, 0xFE]);
      // Length 2 is < 0x80, so encoded as 0x02
      expect(writer.toBytes(), equals([0x02, 0xCA, 0xFE]));
    });
    
    test('writes visible string correctly', () {
      final writer = AxdrWriter();
      writer.writeVisibleString('DLMS');
      expect(writer.toBytes(), equals([0x04, 0x44, 0x4C, 0x4D, 0x53]));
    });
    
    test('expands buffer automatically', () {
      final writer = AxdrWriter(initialCapacity: 1);
      writer.writeUint16(0x1234);
      expect(writer.toBytes(), equals([0x12, 0x34]));
    });
  });

  group('AxdrReader', () {
    test('reads boolean', () {
      final reader = AxdrReader(Uint8List.fromList([0x01, 0x00]));
      expect(reader.readBoolean(), isTrue);
      expect(reader.readBoolean(), isFalse);
    });

    test('reads integers', () {
      final reader = AxdrReader(Uint8List.fromList([0xFF, 0x12, 0x34]));
      expect(reader.readUint8(), 255);
      expect(reader.readUint16(), 0x1234);
    });

    test('reads octet string', () {
      final reader = AxdrReader(Uint8List.fromList([0x02, 0xCA, 0xFE]));
      expect(reader.readOctetString(), equals([0xCA, 0xFE]));
    });
    
     test('reads visible string', () {
      final reader = AxdrReader(Uint8List.fromList([0x04, 0x44, 0x4C, 0x4D, 0x53]));
      expect(reader.readVisibleString(), equals('DLMS'));
    });

    test('throws on buffer underflow', () {
      final reader = AxdrReader(Uint8List.fromList([0x01]));
      expect(() => reader.readUint16(), throwsRangeError);
    });
  });
}
