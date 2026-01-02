import 'package:dlms/dlms.dart';
import 'package:test/test.dart';
import 'dart:typed_data';
import 'mocks/mock_transport.dart';

void main() {
  group('Interface Classes', () {
    late MockTransport transport;
    late DlmsClient client;
    // Helper for successful connection
    final connectResponse = Uint8List.fromList([
      0x61, 0x0C, 0xA2, 0x03, 0x02, 0x01, 0x00, 0xBE, 0x05, 0x04, 0x03, 0x08, 0x00, 0x00
    ]);

    setUp(() {
      transport = MockTransport();
      client = DlmsClient(transport);
    });

    test('CosemClock reads time', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC0) {
          // GetRequest for Clock (Class 8, Attr 2)
          // Return OctetString (Tag 09) 12 bytes
          // Year 2023 (07 E7), Mon 10, Day 25 ...
          return Uint8List.fromList([
            0xC4, 0x01, 0x81, 0x00, 
            0x09, 0x0C, // OctetString Len 12
            0x07, 0xE7, 0x0A, 0x19, 0x03, 0x0C, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00
          ]);
        }
        return Uint8List(0);
      };

      await client.connect();
      final clock = CosemClock(client, ObisCode(0, 0, 1, 0, 0, 255));
      final dt = await clock.time;
      
      expect(dt.year, 2023);
      expect(dt.month, 10);
      expect(dt.day, 25);
    });

    test('CosemRegister reads value', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC0) {
          // GetRequest for Register (Class 3, Attr 2)
          return Uint8List.fromList([
             0xC4, 0x01, 0x81, 0x00, 
             17, 100 // Unsigned 100
          ]);
        }
        return Uint8List(0);
      };

      await client.connect();
      final reg = CosemRegister(client, ObisCode(1, 0, 1, 8, 0, 255));
      final val = await reg.value;
      
      expect(val, 100);
    });

    test('CosemProfileGeneric reads buffer', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC0) {
           // GetRequest for Profile (Class 7, Attr 2)
           // Return Array of Struct
           return Uint8List.fromList([
             0xC4, 0x01, 0x81, 0x00,
             0x01, 0x01, // Array Len 1
             0x02, 0x02, // Struct Len 2
             17, 10, // Data 1
             17, 20  // Data 2
           ]);
        }
        return Uint8List(0);
      };

      await client.connect();
      final profile = CosemProfileGeneric(client, ObisCode(1, 0, 99, 1, 0, 255));
      final rows = await profile.getBuffer();
      
      expect(rows.length, 1);
      expect(rows[0].length, 2);
      expect(rows[0][0], 10);
    });

    test('CosemDisconnectControl operates', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        
        // Read Output State (Attr 2) -> Boolean True
        if (request[0] == 0xC0 && request[12] == 0x02) {
          return Uint8List.fromList([
             0xC4, 0x01, 0x81, 0x00, 
             3, 1 // Boolean True (01)
          ]);
        }
        
        // Remote Disconnect (Method 1) -> Action Response Success
        if (request[0] == 0xC3 && request[12] == 0x01) {
           return Uint8List.fromList([0xC7, 0x01, 0x81, 0x00]);
        }

        return Uint8List(0);
      };

      await client.connect();
      final breaker = CosemDisconnectControl(client, ObisCode(0, 0, 96, 3, 10, 255));
      
      final state = await breaker.outputState;
      expect(state, isTrue);

      await breaker.remoteDisconnect();
    });
  });
}
