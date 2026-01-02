import 'dart:typed_data';
import 'package:dlms/dlms.dart';

// A mock transport to simulate a meter connection for this example.
// In a real app, use TcpTransport or HdlcTransport.
class MockTransport extends DlmsTransport {
  @override
  Stream<Uint8List> get stream => const Stream.empty();

  @override
  Future<void> connect() async => print('Connected to Mock Meter.');

  @override
  Future<void> disconnect() async => print('Disconnected.');

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<Uint8List> sendRequest(
    Uint8List request, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // 1. Association Response (AARE)
    if (request[0] == 0x60) {
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
        0xA2,
        0x03,
        0x02,
        0x01,
        0x00,
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
    // 2. GetResponse for Active Energy (1.0.1.8.0.255)
    if (request[0] == 0xC0) {
      // Return 123456 Wh (Unsigned32)
      return Uint8List.fromList([
        0xC4,
        0x01,
        0x81,
        0x00,
        0x06,
        0x00,
        0x01,
        0xE2,
        0x40,
      ]);
    }
    return Uint8List(0);
  }
}

void main() async {
  // 1. Initialize Client
  final transport = MockTransport();
  // For real usage: final transport = TcpTransport('192.168.1.10', 4059);

  final client = DlmsClient(transport);

  try {
    // 2. Connect
    await client.connect();

    // 3. Read Active Energy Import (+A)
    final energyObis = ObisCode(1, 0, 1, 8, 0, 255);
    final register = CosemRegister(client, energyObis);

    print('Reading Active Energy...');
    final value = await register.value;

    print('Current Energy: $value');
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.disconnect();
  }
}
