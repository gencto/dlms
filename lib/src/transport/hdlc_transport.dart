import 'dart:async';
import 'dart:typed_data';
import 'dlms_transport.dart';
import 'hdlc_frame.dart';

/// Transport implementation for HDLC (Serial/Optical).
///
/// Wraps a low-level byte stream (e.g., from a serial port) with HDLC framing.
class HdlcTransport extends DlmsTransport {
  // In a real app, this would be a serial port stream.
  // For the library, we assume the user provides a way to read/write raw bytes.
  final Stream<Uint8List> byteStream;
  final void Function(Uint8List) byteSink;
  
  final int clientAddress;
  final int serverAddress;
  
  int _receiveSequence = 0;
  int _sendSequence = 0;

  HdlcTransport({
    required this.byteStream,
    required this.byteSink,
    this.clientAddress = 0x21,
    this.serverAddress = 0x03,
  });

  @override
  Future<void> connect() async {
    // 1. Send SNRM (Set Normal Response Mode)
    // Control: 0x80 | 0x03 | 0x10? No, SNRM is 0x83 or 0x93.
    // Standard SNRM control is 0x93.
    final snrm = HdlcFrame(
      destAddress: serverAddress,
      srcAddress: clientAddress,
      control: 0x93, // SNRM
    );
    
    byteSink(snrm.toBytes());
    
    // 2. Wait for UA (Unnumbered Acknowledgment) - 0x73 or 0x63
    final response = await _waitForFrame();
    if (response.control != 0x73 && response.control != 0x63) {
      throw Exception('Failed to establish HDLC connection: Expected UA');
    }
  }

  @override
  Future<void> disconnect() async {
    final disc = HdlcFrame(
      destAddress: serverAddress,
      srcAddress: clientAddress,
      control: 0x53, // DISC
    );
    byteSink(disc.toBytes());
    await _waitForFrame();
  }

  @override
  Future<void> send(Uint8List data) async {
    // For HDLC, raw send is usually not used directly for PDUs, 
    // but we can implement it by wrapping in an I-Frame if needed.
    await sendRequest(data);
  }

  @override
  Stream<Uint8List> get stream => byteStream;

  @override
  Future<Uint8List> sendRequest(Uint8List request, {Duration timeout = const Duration(seconds: 5)}) async {
    // Send I-Frame (Information)
    // Control: N(R) | P | N(S) | 0
    // Simplified: No windowing, just increment
    int control = (_receiveSequence << 5) | (_sendSequence << 1) | 0x10; // P bit set
    
    final iFrame = HdlcFrame(
      destAddress: serverAddress,
      srcAddress: clientAddress,
      control: control,
      information: request,
    );
    
    byteSink(iFrame.toBytes());
    _sendSequence = (_sendSequence + 1) % 8;
    
    // We use the provided timeout
    final response = await _waitForFrame().timeout(timeout);
    
    // Update receive sequence
    _receiveSequence = (response.control >> 5) & 0x07;
    
    return response.information ?? Uint8List(0);
  }

  Future<HdlcFrame> _waitForFrame() async {
    // In a real implementation, we would buffer bytes until we find 0x7E ... 0x7E
    final bytes = await byteStream.first; 
    return HdlcFrame.fromBytes(bytes);
  }
}
