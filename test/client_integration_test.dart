import 'package:dlms/dlms.dart';
import 'package:test/test.dart';
import 'dart:typed_data';
import 'mocks/mock_transport.dart';

void main() {
  group('DlmsClient Integration', () {
    late MockTransport transport;
    late DlmsClient client;

    setUp(() {
      transport = MockTransport();
      client = DlmsClient(transport);
    });

    test('successfully connects with valid AARE', () async {
      // Setup the mock to respond to AARQ with a valid AARE
      transport.onRequest = (request) async {
        // Verify it is an AARQ (starts with 0x60)
        expect(request[0], 0x60);
        
        // Return a valid AARE (Tag 0x61)
        // AARE: [61] [Len] ... [A2] [03] [02] [01] [00] (Result: Accepted)
        return Uint8List.fromList([
          0x61, 0x1F, // AARE tag + length
          0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01, // App Context
          0xA2, 0x03, 0x02, 0x01, 0x00, // Result: 0 (Accepted) - Explicit Integer
          0xBE, 0x0D, // User Info
            0x04, 0x0B, // Octet String
              0x08, 0x00, 0x06, 0x5F, 0x1F, 0x04, 0x00, 0x00, 0x1E, 0x1D, 0x04, 0x00 // xDLMS InitiateResponse (dummy bytes)
        ]);
      };

      final result = await client.connect();
      expect(result, isTrue);
      expect(client.isConnected, isTrue);
    });

    test('fails to connect if meter rejects association', () async {
      transport.onRequest = (request) async {
        // Return AARE with Result: 1 (Rejected Permanent)
        return Uint8List.fromList([
          0x61, 0x0D,
          0xA2, 0x03, 0x02, 0x01, 0x01, // Result: 1 (Rejected)
          0xBE, 0x06, 0x04, 0x04, 0x08, 0x00, 0x00, 0x00 // Dummy User Info
        ]);
      };

      final result = await client.connect();
      expect(result, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('reads attribute successfully', () async {
      // Simulate connected state
      await transport.connect();
      // Manually set client connected flag? 
      // DlmsClient doesn't expose a setter, so we must go through connect() or mock internal state.
      // Let's just do a full flow.
      
      // 1. Connect handler
      transport.onRequest = (request) async {
        if (request[0] == 0x60) {
           // Fixed length: Payload is 12 bytes (A2...00)
           return Uint8List.fromList([0x61, 0x0C, 0xA2, 0x03, 0x02, 0x01, 0x00, 0xBE, 0x05, 0x04, 0x03, 0x08, 0x00, 0x00]);
        }
        if (request[0] == 0xC0) { // GetRequest
           // Return GetResponseNormal (C4 01)
           // Invoke ID (81)
           // Result: Data (00)
           // Type: Unsigned (17) Value: 123
           return Uint8List.fromList([0xC4, 0x01, 0x81, 0x00, 17, 123]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      final val = await client.read(3, ObisCode(1, 0, 1, 8, 0, 255), 2);
      expect(val.type, 17);
      expect(val.value, 123);
    });

    test('throws exception on meter error response', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) {
           return Uint8List.fromList([0x61, 0x0C, 0xA2, 0x03, 0x02, 0x01, 0x00, 0xBE, 0x05, 0x04, 0x03, 0x08, 0x00, 0x00]);
        }
        if (request[0] == 0xC0) {
           // Return GetResponseNormal (C4 01)
           // Invoke ID (81)
           // Result: Data-Access-Result (01) -> Access Violation (05)
           return Uint8List.fromList([0xC4, 0x01, 0x81, 0x01, 0x05]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      expect(
        () => client.read(3, ObisCode(1, 0, 1, 8, 0, 255), 2),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Data Access Result 5'))),
      );
    });
  });
}
