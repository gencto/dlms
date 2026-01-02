import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dlms_transport.dart';

/// TCP/IP Transport for DLMS (Wrapper for [Socket]).
///
/// Handles the specific DLMS/IP encapsulation (sometimes just raw TCP stream,
/// but often wrapped with a 4-byte header in some variants, though pure
/// wrapper often assumes direct PDU access).
/// For standard DLMS over IP (IEC 62056-47), it usually involves a specific wrapper header.
///
/// Wrapper Header (8 bytes):
/// - Version (2 bytes)
/// - Source WPort (2 bytes)
/// - Dest WPort (2 bytes)
/// - Length (2 bytes)
class TcpTransport implements DlmsTransport {
  final String host;
  final int port;
  Socket? _socket;
  StreamController<Uint8List>? _controller;

  // Wrapper fields
  final int clientAddress;
  final int serverAddress;

  TcpTransport(
    this.host,
    this.port, {
    this.clientAddress = 16,
    this.serverAddress = 1,
  });

  @override
  Stream<Uint8List> get stream => _controller?.stream ?? const Stream.empty();

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _controller = StreamController<Uint8List>.broadcast();

    _socket!.listen(
      (data) {
        _controller?.add(data);
      },
      onError: (e) {
        _controller?.addError(e);
        disconnect();
      },
      onDone: () {
        disconnect();
      },
    );
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    await _controller?.close();
    _socket = null;
    _controller = null;
  }

  @override
  Future<void> send(Uint8List data) async {
    if (_socket == null) throw StateError('Not connected');

    // Wrap data in DLMS/IP header (IEC 62056-47)
    // Version: 0x0001
    // Source Port: clientAddress
    // Dest Port: serverAddress
    // Length: Data Length (inclusive of header? usually just payload, need to verify spec.
    // Actually, Wrapper length usually includes the header itself in some implementations,
    // or just payload. The standard says: Length of the data field.

    final header = ByteData(8);
    header.setUint16(0, 0x0001); // Version
    header.setUint16(2, clientAddress); // Source
    header.setUint16(4, serverAddress); // Destination
    header.setUint16(6, data.length); // Length of the payload

    _socket!.add(header.buffer.asUint8List() + data);
    await _socket!.flush();
  }

  @override
  Future<Uint8List> sendRequest(
    Uint8List request, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_socket == null) await connect();

    final completer = Completer<Uint8List>();
    final buffer = BytesBuilder(); // Reconstruct fragmented TCP packets

    // Simple one-shot listener for response (naive implementation for Phase 1)
    // In production, this needs a proper state machine to handle PDU boundaries.
    final subscription = stream.listen((data) {
      buffer.add(data);
      // Basic check: do we have enough data?
      // We need to parse the wrapper header to know the expected length.
      if (buffer.length >= 8) {
        final view = ByteData.sublistView(Uint8List.fromList(buffer.toBytes()));
        final expectedLen = view.getUint16(6);
        if (buffer.length >= 8 + expectedLen) {
          completer.complete(
            Uint8List.fromList(buffer.toBytes().sublist(8, 8 + expectedLen)),
          ); // Return payload only
        }
      }
    });

    try {
      await send(request);
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }
}
