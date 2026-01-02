import 'package:dlms/dlms.dart';
import 'package:test/test.dart';

import '../bin/dlms_simulator.dart'; // Import the simulator class
import 'mocks/mock_hls.dart'; // Reuse mock mechanism

void main() {
  late DlmsSimulator simulator;
  final int port = 4060; // Use distinct port for test

  setUpAll(() async {
    simulator = DlmsSimulator(port: port);
    await simulator.start();
  });

  tearDownAll(() async {
    await simulator.stop();
  });

  group('E2E Integration Test', () {
    test('Connects and Reads Energy (LLS/None)', () async {
      final transport = TcpTransport('127.0.0.1', port);
      final client = DlmsClient(transport);

      try {
        await client.connect();
        expect(client.isConnected, isTrue);

        final energyObis = ObisCode(1, 0, 1, 8, 0, 255);
        final register = CosemRegister(client, energyObis);

        final val = await register.value;
        expect(val, greaterThan(1000));

        // Read again to verify increment
        final val2 = await register.value;
        expect(val2, equals(val + 1));
      } finally {
        await client.disconnect();
      }
    });

    test('HLS Handshake Success', () async {
      // Configure simulator to require HLS
      simulator.requireHls = true;

      final transport = TcpTransport('127.0.0.1', port);
      final client = DlmsClient(transport);

      try {
        final hls = MockHlsMechanism();
        await client.connect(hls: hls);

        expect(client.isConnected, isTrue);

        // Verify we can read data (authenticated)
        final energyObis = ObisCode(1, 0, 1, 8, 0, 255);
        final register = CosemRegister(client, energyObis);
        final val = await register.value;
        expect(val, greaterThan(1000));
      } finally {
        await client.disconnect();
        simulator.requireHls = false; // Reset
      }
    });

    test('Control Breaker', () async {
      final transport = TcpTransport('127.0.0.1', port);
      final client = DlmsClient(transport);

      try {
        await client.connect();

        final breaker = CosemDisconnectControl(
          client,
          ObisCode(0, 0, 96, 3, 10, 255),
        );

        // Initial state
        bool state = await breaker.outputState;
        expect(state, isTrue); // Simulator defaults to Closed/Connected

        // Disconnect
        await breaker.remoteDisconnect();

        // In real simulator we might toggle state, but current simple mock just accepts action.
        // We verify no exception thrown.
      } finally {
        await client.disconnect();
      }
    });

    test('Reads Large Load Profile (Block Transfer)', () async {
      final transport = TcpTransport('127.0.0.1', port);
      final client = DlmsClient(transport);

      try {
        await client.connect();

        final profileObis = ObisCode(1, 0, 99, 1, 0, 255);
        final profile = CosemProfileGeneric(client, profileObis);

        final buffer = await profile.getBuffer();

        expect(buffer.length, 50); // Simulator generates 50 rows
        expect(buffer[0][1], 0); // Row 0 value
        expect(buffer[49][1], 490); // Row 49 value (49 * 10)
      } finally {
        await client.disconnect();
      }
    });
  });
}
