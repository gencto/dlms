import 'dart:async';
import 'dart:typed_data';
import 'package:dlms/dlms.dart';

/// A Mock Transport that simulates a DLMS Meter.
/// 
/// It mimics a request-response cycle.
class MockTransport implements DlmsTransport {
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  bool _connected = false;
  
  // Handler for incoming requests. Returns the bytes to send back.
  Future<Uint8List> Function(Uint8List request)? onRequest;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _streamController.close();
  }

  @override
  Future<void> send(Uint8List data) async {
    if (!_connected) throw StateError('Not connected');
    
    if (onRequest != null) {
      final response = await onRequest!(data);
      _streamController.add(response);
    }
  }

  @override
  Future<Uint8List> sendRequest(Uint8List request, {Duration timeout = const Duration(seconds: 5)}) async {
    if (!_connected) throw StateError('Not connected');

    if (onRequest != null) {
      return await onRequest!(request);
    }
    throw UnimplementedError('No request handler set in MockTransport');
  }

  @override
  Stream<Uint8List> get stream => _streamController.stream;
}
