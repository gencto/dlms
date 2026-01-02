import 'package:dlms/dlms.dart';
import 'package:test/test.dart';
import 'dart:typed_data';
import 'mocks/mock_transport.dart';

void main() {
  group('Advanced COSEM Operations', () {
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

    test('write (SetRequest) successfully', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;

        if (request[0] == 0xC1) { // SetRequest
          // Verify we got the correct request
          // C1 01 81 (Invoke) ...
          
          // Return SetResponseNormal (C5 01)
          // Invoke ID (81)
          // Result: Success (00)
          return Uint8List.fromList([0xC5, 0x01, 0x81, 0x00]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      final obis = ObisCode(1, 0, 1, 8, 0, 255);
      await client.write(3, obis, 2, const DlmsValue(100, 15)); // Write int8: 100
    });

    test('write throws on error result', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC1) { 
          // Return SetResponseNormal with Error (e.g., Read Only)
          // Result: Read Only (03) - example
          return Uint8List.fromList([0xC5, 0x01, 0x81, 0x03]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      expect(
        () => client.write(3, ObisCode(1, 0, 0, 0, 0, 255), 2, const DlmsValue(100, 15)),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Result Code 3'))),
      );
    });

    test('action (Method Invocation) successfully with no params', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC3) { // ActionRequest
          // C3 01 81 ... 
          
          // Return ActionResponseNormal (C7 01)
          // Invoke ID (81)
          // Result: Success (00)
          // Optional Return Params: Not present (no byte, or 00?)
          // ActionResponseNormal SEQUENCE { invokeId, single-response SEQUENCE { result, return-params OPTIONAL } }
          // If return-params is OPTIONAL, there should be presence indicator if following A-XDR?
          // Wait, earlier I saw my ActionResponsePdu implementation:
          // if (reader.remaining > 0) ...
          // So if we just stop here, it implies no params.
          return Uint8List.fromList([0xC7, 0x01, 0x81, 0x00]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      final obis = ObisCode(0, 0, 10, 0, 0, 255); // Script Table
      final result = await client.action(8, obis, 1); // Execute
      expect(result, isNull);
    });

    test('action successfully with return params', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC3) { 
          // Return ActionResponseNormal (C7 01)
          // Invoke ID (81)
          // Result: Success (00)
          // Optional Return Params: Present (01)
          // Data: Unsigned (17) Value: 42
          return Uint8List.fromList([0xC7, 0x01, 0x81, 0x00, 0x01, 17, 42]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      final obis = ObisCode(0, 0, 10, 0, 0, 255);
      final result = await client.action(8, obis, 1);
      
      expect(result, isNotNull);
      expect(result!.value, 42);
    });

    test('action throws on error result', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        if (request[0] == 0xC3) { 
          // Result: Temporary Failure (02)
          return Uint8List.fromList([0xC7, 0x01, 0x81, 0x02]);
        }
        return Uint8List(0);
      };

      await client.connect();
      
      expect(
        () => client.action(8, ObisCode(0, 0, 10, 0, 0, 255), 1),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Result Code 2'))),
      );
    });

    test('read handles multi-block transfer automatically', () async {
      int requestCount = 0;
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        
        requestCount++;
        if (requestCount == 1) {
          // First request (GetRequestNormal)
          // Return GetResponseWithBlock (C4 02), lastBlock=false(00), block=1(00000001)
          // Choice: raw-data (00). Data: Part 1 of an OctetString (Tag 09, Len 4, "ABCD"...)
          // Actually, let's just send half of a DlmsValue(Unsigned, 123) -> [17, 123]
          // But usually blocks contain the raw bytes of the encoded stream.
          return Uint8List.fromList([
            0xC4, 0x02, 0x81, // Tag, Type 2, Invoke
            0x00, // Last block = false
            0x00, 0x00, 0x00, 0x01, // Block number 1
            0x00, // Choice: raw-data
            0x01, 17, // OctetString length 1, Byte 17 (Type: Unsigned)
          ]);
        } else {
          // Second request (GetRequestNext)
          // Return GetResponseWithBlock, lastBlock=true(01), block=2
          return Uint8List.fromList([
            0xC4, 0x02, 0x81, 
            0x01, // Last block = true
            0x00, 0x00, 0x00, 0x02, // Block number 2
            0x00, // Choice: raw-data
            0x01, 123, // OctetString length 1, Byte 123 (Value)
          ]);
        }
      };

      await client.connect();
      final val = await client.read(3, ObisCode(1, 0, 1, 8, 0, 255), 2);
      
      expect(val.type, 17);
      expect(val.value, 123);
      expect(requestCount, 2);
    });

    test('read with RangeDescriptor sends correct bytes', () async {
      transport.onRequest = (request) async {
        if (request[0] == 0x60) return connectResponse;
        
        if (request[0] == 0xC0) {
           // Verify Access Selector is present
           // 0xC0 01 81 ... 01 (present) 01 (selector=1)
           // It's at the end of the PDU.
           // Normal GetRequest length approx 14 bytes + Selector params
           
           // Simple check: Look for the RangeDescriptor specific bytes
           // We'll trust the encoding if the PDU structure is generally correct
           // But let's verify we see the "01" (selector 1)
           // Index: C0(0) 01(1) 81(2) Class(3-4) Obis(5-11) Attr(12) Present(13) Selector(14)
           if (request.length > 14 && request[13] == 0x01 && request[14] == 0x01) {
              // Return GetResponseNormal (C4 01)
              // Invoke (81)
              // Result Choice (00 - Data)
              // DlmsValue: Array (01) Length (00) -> Empty List
              return Uint8List.fromList([0xC4, 0x01, 0x81, 0x00, 0x01, 0x00]); 
           }
        }
        return Uint8List(0);
      };

      await client.connect();
      
      // Range: 2023-01-01 to 2023-01-02
      // Restricted Object: Clock (8.0.0.1.0.255) capture col index 2?
      // Mocking values for the descriptor
      final range = RangeDescriptor(
        restrictedObject: const DlmsValue(<DlmsValue>[], 2), // dummy struct
        fromValue: const DlmsValue('2023-01-01', 10), // string date
        toValue: const DlmsValue('2023-01-02', 10),
        selectedValues: <DlmsValue>[],
      );
      
      final val = await client.read(7, ObisCode(1, 0, 99, 1, 0, 255), 2, selector: range);
      expect(val.type, 1); // Array
    });
  });
}
