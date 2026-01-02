import 'package:dlms/dlms.dart';
import 'dart:typed_data';
import 'dart:async'; // Added for Stream

// Mock Transport for example
class MockTcpTransport extends DlmsTransport {
  final String host;
  final int port;

  MockTcpTransport(this.host, this.port);

  @override
  Stream<Uint8List> get stream => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> connect() async {
    print('Connecting to $host:$port...');
    await Future.delayed(const Duration(milliseconds: 100));
    print('Connected.');
  }

  @override
  Future<void> disconnect() async {
    print('Disconnected.');
  }

  @override
  Future<Uint8List> sendRequest(
    Uint8List request, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Determine request type
    if (request[0] == 0x60) {
      // AARQ -> AARE (Accepted)
      return Uint8List.fromList([
        0x61,
        0x1F,
        0xA1,
        0x09,
        0x06,
        0x07,
        0x60,
        0x85,
        0x74,
        0x05,
        0x08,
        0x01,
        0x01,
        0xA2, 0x03, 0x02, 0x01, 0x00, // Result: 0
        0xBE,
        0x0D,
        0x04,
        0x0B,
        0x08,
        0x00,
        0x06,
        0x5F,
        0x1F,
        0x04,
        0x00,
        0x00,
        0x1E,
        0x1D,
        0x04,
        0x00,
      ]);
    }

    if (request[0] == 0xC0) {
      print('Sending GetRequest...');
      // Simulate Profile Buffer Response (Array of Structures)
      // Structure: { Clock, Energy }
      // Let's return 1 row: [ "2023-10-01 12:00", 1500 kWh ]
      // Type 1 (Array) Length 1
      //   Type 2 (Struct) Length 2
      //     Type 10 (String) "2023..."
      //     Type 6 (Uint32) 1500

      // Encoded bytes for the above:
      // Array: 01 01
      // Struct: 02 02
      // String: 0A 10 (Len 16) 32 30 32 33...
      // Uint32: 06 00 00 05 DC (1500)

      // Simplified response
      return Uint8List.fromList([
        0xC4, 0x01, 0x81, 0x00, // Header
        0x01, 0x01, // Array len 1
        0x02, 0x02, // Struct len 2
        0x11, 100, // Unsigned 100 (Dummy Date)
        0x11, 200, // Unsigned 200 (Energy)
      ]);
    }

    return Uint8List(0);
  }
}

void main() async {
  final transport = MockTcpTransport('192.168.1.100', 4059);
  final client = DlmsClient(transport);

  try {
    await client.connect();
    print('Association established.');

    // 1. Read Current Energy (Simple Read)
    print('\nReading Active Energy...');
    final energy = await client.read(3, ObisCode(1, 0, 1, 8, 0, 255), 2);
    print('Energy: ${energy.value} Wh');

    // 2. Read Load Profile with Selective Access (Range)
    print('\nReading Load Profile (Buffer) with Range...');

    // Define the range: Last 24 hours (Mocked parameters)
    // In real DLMS, date/time is OctetString (12 bytes)
    final range = RangeDescriptor(
      restrictedObject: const DlmsValue([], 2), // Columns definition
      fromValue: const DlmsValue(0, 6), // Start Time
      toValue: const DlmsValue(0, 6), // End Time
      selectedValues: [], // Select all columns
    );

    final profileData = await client.read(
      7, // Profile Generic
      ObisCode(1, 0, 99, 1, 0, 255),
      2, // Buffer
      selector: range,
    );

    print('Profile Data Type: ${profileData.type}');
    print('Profile Rows: ${(profileData.value as List).length}');

    final row = (profileData.value as List)[0];
    print('Row 1: $row');
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.disconnect();
  }
}
