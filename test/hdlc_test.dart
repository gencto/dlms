import 'package:dlms/dlms.dart';
import 'package:dlms/src/transport/hdlc_transport.dart';
import 'package:dlms/src/transport/hdlc_frame.dart';
import 'package:test/test.dart';
import 'dart:typed_data';
import 'dart:async';

void main() {
  group('HDLC Transport', () {
    test('SNRM/UA Handshake', () async {
      final controller = StreamController<Uint8List>();
      final outBytes = <Uint8List>[];

      final transport = HdlcTransport(
        byteStream: controller.stream,
        byteSink: (b) => outBytes.add(b),
        clientAddress: 0x21,
        serverAddress: 0x03,
      );

      // Start connect in background
      final connectFuture = transport.connect();

      // Simulate Meter responding with UA (0x73)
      // We need to construct a valid UA frame.
      // 7E A0 0A 00 00 00 03 21 73 [CRC] 7E
      // (Wait, my frame encoder uses 4 byte dest, 1 byte src)
      // Dest: 00 00 00 03 -> 00 00 00 07? DLMS address encoding is tricky.

      // Let's use the HdlcFrame class itself to generate the mock response
      final uaFrame = const HdlcFrame(
        destAddress: 0x21,
        srcAddress: 0x03,
        control: 0x73,
      ).toBytes();

      controller.add(uaFrame);

      await connectFuture;

      expect(outBytes.length, 1);
      expect(outBytes[0][bytesToControlOffset(outBytes[0])], 0x93); // Sent SNRM
    });
  });
}

int bytesToControlOffset(Uint8List frame) {
  // 7E (1) + Format (2) + Dest(4) + Src(1) = 8
  return 8;
}
