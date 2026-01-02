import 'package:dlms/dlms.dart';
import 'dart:typed_data';

// Mock Transport for example (simulating a meter)
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
  Future<Uint8List> sendRequest(Uint8List request, {Duration timeout = const Duration(seconds: 5)}) async {
    // 1. AARQ -> AARE (Association Accepted)
    if (request[0] == 0x60) {
      return Uint8List.fromList([
        0x61, 0x1F, 0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01,
        0xA2, 0x03, 0x02, 0x01, 0x00, 
        0xBE, 0x0D, 0x04, 0x0B, 0x08, 0x00, 0x06, 0x5F, 0x1F, 0x04, 0x00, 0x00, 0x1E, 0x1D, 0x04, 0x00
      ]);
    }
    
    // 2. GetRequest (Class 70, Attr 2 - Output State)
    if (request[0] == 0xC0 && request[12] == 0x02) {
      print('-> Reading Breaker State...');
      // Return Boolean: True (Connected)
      return Uint8List.fromList([0xC4, 0x01, 0x81, 0x00, 0x03, 0x01]);
    }
    
    // 3. ActionRequest (Class 70, Method 1 - Disconnect)
    if (request[0] == 0xC3 && request[12] == 0x01) {
      print('-> Sending Remote Disconnect Command...');
      // Return ActionResponse: Success
      return Uint8List.fromList([0xC7, 0x01, 0x81, 0x00]);
    }
    
    return Uint8List(0);
  }
}

void main() async {
  // 1. Setup
  final transport = MockTcpTransport('192.168.1.50', 4059);
  final client = DlmsClient(transport);

  try {
    await client.connect();

    // 2. Initialize the Disconnect Control Object
    // Standard OBIS for Disconnect Control is often 0.0.96.3.10.255
    final breakerObis = ObisCode(0, 0, 96, 3, 10, 255);
    final breaker = CosemDisconnectControl(client, breakerObis);

    // 3. Check Current State
    bool isConnected = await breaker.outputState;
    print('Breaker Status: ${isConnected ? "CONNECTED" : "DISCONNECTED"}');

    // 4. Perform Action
    if (isConnected) {
      print('Initiating disconnection...');
      await breaker.remoteDisconnect();
      print('Disconnection command sent successfully.');
    } else {
      print('Breaker is already open.');
    }

  } catch (e) {
    print('Error: $e');
  } finally {
    await client.disconnect();
  }
}
