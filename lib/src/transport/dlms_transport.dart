import 'dart:typed_data';

/// Abstract base class for DLMS transport layers (TCP, HDLC, etc.).
abstract class DlmsTransport {
  /// Connects to the remote meter/server.
  Future<void> connect();

  /// Disconnects from the remote meter/server.
  Future<void> disconnect();

  /// Sends raw bytes to the meter.
  Future<void> send(Uint8List data);

  /// Receives data from the meter.
  /// 
  /// Returns a stream of data chunks or a complete PDU depending on implementation.
  /// For simplicity in this phase, we might just expose a raw stream or a read method.
  Stream<Uint8List> get stream;
  
  /// Helper to send and wait for a response (simplistic request/reply).
  Future<Uint8List> sendRequest(Uint8List request, {Duration timeout = const Duration(seconds: 5)});
}
