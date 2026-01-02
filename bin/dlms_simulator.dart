import 'dart:io';
import 'dart:typed_data';
import 'package:dlms/dlms.dart';

/// A simple DLMS Meter Simulator.
/// 
/// Listens on TCP port 4059 (default) and responds to requests.
class DlmsSimulator {
  final int port;
  ServerSocket? _server;
  
  // Simulated State
  final bool _breakerOpen = false;
  int _energyCounter = 1000;
  
  // Configuration
  bool requireHls = false;
  
  // HLS State
  bool _authenticated = false;
  Uint8List? _serverChallenge;

  DlmsSimulator({this.port = 4059});

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    // print('DLMS Simulator listening on port $port');
    _server!.listen(_handleConnection);
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  void _handleConnection(Socket socket) {
    // New connection resets auth state
    _authenticated = false; 
    _serverChallenge = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]);

    socket.listen(
      (data) => _handleData(socket, Uint8List.fromList(data)),
      onError: (e) {}, // print('Socket error: $e'),
      onDone: () {}, // print('Client disconnected'),
    );
  }

  void _handleData(Socket socket, Uint8List data) {
    if (data.isEmpty) return;
    
    // Check for DLMS/IP Wrapper (Version 0x0001)
    int pduOffset = 0;
    int clientAddr = 16;
    int serverAddr = 1;
    
    if (data.length >= 8 && data[0] == 0x00 && data[1] == 0x01) {
       // Extract addresses to swap them for response
       final view = ByteData.sublistView(data);
       clientAddr = view.getUint16(2); // Src
       serverAddr = view.getUint16(4); // Dest
       final len = view.getUint16(6);
       
       pduOffset = 8;
       // Ensure we have the full PDU
       if (data.length < 8 + len) {
         // Fragmented? For sim, assume full frame for now.
         return; 
       }
    }

    final pdu = data.sublist(pduOffset);
    if (pdu.isEmpty) return;

    final tag = pdu[0]; // Peek tag

    try {
      if (tag == 0x60) { // AARQ
        if (requireHls) {
           _send(socket, _buildAareHls(), clientAddr, serverAddr);
        } else {
           _authenticated = true; // LLS/None assumed success
           _send(socket, _buildAare(), clientAddr, serverAddr);
        }
      } else if (tag == 0xC0) { // GetRequest
        _handleGetRequest(socket, pdu, clientAddr, serverAddr);
      } else if (tag == 0xC1) { // SetRequest
        _handleSetRequest(socket, pdu, clientAddr, serverAddr);
      } else if (tag == 0xC3) { // ActionRequest
        _handleActionRequest(socket, pdu, clientAddr, serverAddr);
      }
    } catch (e) {
      // print('Error handling PDU: $e');
    }
  }
  
  void _send(Socket socket, Uint8List data, int destAddr, int srcAddr) {
     // Wrap response
     final header = ByteData(8);
     header.setUint16(0, 0x0001); // Version
     header.setUint16(2, srcAddr); // Me (Server)
     header.setUint16(4, destAddr); // Target (Client)
     header.setUint16(6, data.length);
     
     socket.add(header.buffer.asUint8List() + data);
  }

  Uint8List _buildAare() {
    return Uint8List.fromList([
        0x61, 0x1F, 0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01,
        0xA2, 0x03, 0x02, 0x01, 0x00, 
        0xBE, 0x0D, 0x04, 0x0B, 0x08, 0x00, 0x06, 0x5F, 0x1F, 0x04, 0x00, 0x00, 0x1E, 0x1D, 0x04, 0x00
    ]);
  }
  
  Uint8List _buildAareHls() {
    final stoc = _serverChallenge!;
    final builder = BytesBuilder();
    
    // Header
    builder.add([0x61, 0x2C, 0xA1, 0x09, 0x06, 0x07, 0x60, 0x85, 0x74, 0x05, 0x08, 0x01, 0x01]);
    // Result 0
    builder.add([0xA2, 0x03, 0x02, 0x01, 0x00]);
    // Auth Value (AA) - StoC
    builder.addByte(0xAA);
    builder.addByte(2 + 2 + stoc.length); // A0 + 04 + Bytes
    builder.addByte(0xA0);
    builder.addByte(2 + stoc.length);
    builder.addByte(0x04);
    builder.addByte(stoc.length);
    builder.add(stoc);
    // User Info
    builder.add([0xBE, 0x0D, 0x04, 0x0B, 0x08, 0x00, 0x06, 0x5F, 0x1F, 0x04, 0x00, 0x00, 0x1E, 0x1D, 0x04, 0x00]);
    
    return builder.toBytes();
  }

  void _handleGetRequest(Socket socket, Uint8List data, int clientAddr, int serverAddr) {
    if (!_authenticated) {
        _send(socket, Uint8List.fromList([0xC4, 0x01, 0x00, 0x01, 0x01]), clientAddr, serverAddr); 
        return;
    }
    
    final reader = AxdrReader(data);
    reader.readUint8(); // Tag C0
    final type = reader.readUint8();
    
    if (type == 2) { // GetRequestNext
       // Parse GetRequestNext
       final invokeId = reader.readUint8();
       final blockNum = reader.readUint32();
       
       // Assume Load Profile (only one supported for now)
       _sendLoadProfileBlock(socket, invokeId, blockNum, clientAddr, serverAddr);
       return;
    }
    
    if (type != 1) return; // Only support Normal and Next
    
    final invokeId = reader.readUint8();
    final classId = reader.readUint16();
    final obis = ObisCode.fromBytes(reader.readOctetString());
    final attrId = reader.readInt8();

    DlmsValue? result;

    // Router
    if (classId == 8 && attrId == 2) { // Clock Time
      result = _createDateTimeValue();
    } else if (classId == 3 && attrId == 2) { // Register Value
      if (obis == ObisCode(1, 0, 1, 8, 0, 255)) { // Active Energy
        _energyCounter++;
        result = DlmsValue(_energyCounter, 6); // Uint32
      }
    } else if (classId == 70 && attrId == 2) { // Disconnect State
       result = DlmsValue(!_breakerOpen, 3); // Boolean (True=Closed/Connected)
    } else if (classId == 7 && attrId == 2 && obis == ObisCode(1, 0, 99, 1, 0, 255)) {
       // Load Profile Buffer - 50 rows
       // Start Block 1
       _sendLoadProfileBlock(socket, invokeId, 1, clientAddr, serverAddr);
       return;
    }

    if (result != null) {
      _sendGetResponse(socket, invokeId, result, clientAddr, serverAddr);
    } else {
      // Error
      _send(socket, Uint8List.fromList([0xC4, 0x01, invokeId, 0x01, 0x01]), clientAddr, serverAddr);
    }
  }

  void _handleSetRequest(Socket socket, Uint8List data, int clientAddr, int serverAddr) {
      if (!_authenticated) return;
      _send(socket, Uint8List.fromList([0xC5, 0x01, data[2], 0x00]), clientAddr, serverAddr);
  }

  void _handleActionRequest(Socket socket, Uint8List data, int clientAddr, int serverAddr) {
    final reader = AxdrReader(data);
    reader.readUint8(); // Tag C3
    reader.readUint8(); // Type 1
    final invokeId = reader.readUint8();
    final classId = reader.readUint16();
    
    if (classId == 15 && requireHls) { // Association LN
       // Verify HLS reply
       _authenticated = true;
    }
    
    _send(socket, Uint8List.fromList([0xC7, 0x01, invokeId, 0x00]), clientAddr, serverAddr);
  }

  void _sendGetResponse(Socket socket, int invokeId, DlmsValue value, int clientAddr, int serverAddr) {
    final writer = AxdrWriter();
    writer.writeUint8(0xC4); // GetResponse
    writer.writeUint8(0x01); // Normal
    writer.writeUint8(invokeId);
    writer.writeUint8(0x00); // Data Choice
    value.encode(writer);
    _send(socket, writer.toBytes(), clientAddr, serverAddr);
  }

  void _sendLoadProfileBlock(Socket socket, int invokeId, int blockNum, int clientAddr, int serverAddr) {
    final fullData = _generateFullProfile();
    final blockSize = 200; 
    
    final totalBlocks = (fullData.length / blockSize).ceil();
    
    if (blockNum > totalBlocks) {
      // Error
      _send(socket, Uint8List.fromList([0xC4, 0x01, invokeId, 0x01, 0x01]), clientAddr, serverAddr);
      return;
    }
    
    final startOffset = (blockNum - 1) * blockSize;
    var endOffset = startOffset + blockSize;
    bool isLast = false;
    
    if (endOffset >= fullData.length) {
      endOffset = fullData.length;
      isLast = true;
    }
    
    final chunk = fullData.sublist(startOffset, endOffset);
    
    final writer = AxdrWriter();
    writer.writeUint8(0xC4); // GetResponse
    writer.writeUint8(0x02); // WithDataBlock
    writer.writeUint8(invokeId);
    writer.writeUint8(isLast ? 0x01 : 0x00); // Last Block
    writer.writeUint32(blockNum);
    writer.writeUint8(0x00); // Result: Raw Data
    writer.writeOctetString(chunk); // The chunk
    
    _send(socket, writer.toBytes(), clientAddr, serverAddr);
  }

  Uint8List _generateFullProfile() {
    final rows = <DlmsValue>[];
    for(int i=0; i<50; i++) {
       rows.add(DlmsValue([
         _createDateTimeValue(), 
         DlmsValue(i * 10, 6),
       ], 2));
    }
    final array = DlmsValue(rows, 1);
    
    final writer = AxdrWriter();
    array.encode(writer);
    return writer.toBytes();
  }

  DlmsValue _createDateTimeValue() {
    final now = DateTime.now();
    final b = <int>[];
    b.add((now.year >> 8) & 0xFF);
    b.add(now.year & 0xFF);
    b.add(now.month);
    b.add(now.day);
    b.add(now.weekday);
    b.add(now.hour);
    b.add(now.minute);
    b.add(now.second);
    b.add(0); b.add(0x80); b.add(0); b.add(0);
    return DlmsValue(b, 9);
  }
}

void main() async {
  final sim = DlmsSimulator();
  await sim.start();
  print('DLMS Simulator running. Press Ctrl+C to stop.');
}
