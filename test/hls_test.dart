import 'package:dlms/dlms.dart';
import 'package:test/test.dart';
import 'dart:typed_data';
import 'mocks/mock_transport.dart';
import 'mocks/mock_hls.dart'; // Import Mock Mechanism

void main() {
  group('HLS Support', () {
    late MockTransport transport;
    late DlmsClient client;

    // Helper for successful connection with StoC challenge
    // AARE with Result 0, and Responding Auth Value (StoC)
    final connectResponseWithStoC = Uint8List.fromList([
      0x61, 0x2A, // AARE Len 42
        0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01, // App Context
        0xA2, 0x03, 0x02, 0x01, 0x00, // Result: 0 (Accepted)
        // Responding Auth Value (AA) - StoC
        0xAA, 0x0A, 
          0xA0, 0x08, 
            0x04, 0x06, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, // Challenge: 01..06
        0xBE, 0x0D, 0x04, 0x0B, 0x08, 0x00, 0x06, 0x5F, 0x1F, 0x04, 0x00, 0x00, 0x1E, 0x1D, 0x04, 0x00
    ]);

    setUp(() {
      transport = MockTransport();
      client = DlmsClient(transport);
    });

    test('Performs 4-pass HLS handshake', () async {
      int step = 0;
      
      transport.onRequest = (request) async {
        if (request[0] == 0x60) {
           // Pass 1: AARQ received
           step++;
           return connectResponseWithStoC; // Return AARE with StoC (Pass 2)
        }
        
        if (request[0] == 0xC3) {
           // Pass 4: ActionRequest (Reply to HLS)
           // Check Method ID 1 on Association Class 15
           // C3 01 81 00 0F (Class 15) ... 01 (Method)
           // Params should contain the response
           step++;
           return Uint8List.fromList([0xC7, 0x01, 0x81, 0x00]); // Action Success
        }
        
        return Uint8List(0);
      };

      final hls = MockHlsMechanism();
      
      final result = await client.connect(hls: hls);
      
      expect(result, isTrue);
      expect(step, 2); // AARQ + ActionRequest
    });
  });
}
