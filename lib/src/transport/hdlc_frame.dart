import 'dart:typed_data';
import 'hdlc_crc.dart';

/// Represents a DLMS HDLC Frame.
class HdlcFrame {
  final int frameType;
  final int destAddress;
  final int srcAddress;
  final int control;
  final Uint8List? information;

  const HdlcFrame({
    this.frameType = 0xA000, // Frame Format Type 3
    required this.destAddress,
    required this.srcAddress,
    required this.control,
    this.information,
  });

  /// Encodes the frame to bytes (including flags and FCS).
  Uint8List toBytes() {
    final payload = BytesBuilder();
    
    // Length is calculated later. 
    // Format: 2 bytes (Type + Length)
    // Address: Variable (usually 4 for dest, 1 for src in many configs)
    // Control: 1 byte
    // Info: Variable
    // FCS: 2 bytes
    
    // For now, we use a fixed address length logic (common in DLMS: 4 bytes dest, 1 byte src)
    _writeAddress(payload, destAddress, 4);
    _writeAddress(payload, srcAddress, 1);
    
    payload.addByte(control);
    
    if (information != null) {
      payload.add(information!);
    }
    
    final headerAndInfo = payload.takeBytes();
    final length = headerAndInfo.length + 2 + 2; // + format bytes + FCS bytes
    
    final finalFrame = BytesBuilder();
    finalFrame.addByte(0x7E); // Flag
    
    // Frame Format (Type 3 = 0xA) + Length (11 bits)
    final format = 0xA000 | (length & 0x07FF);
    finalFrame.addByte((format >> 8) & 0xFF);
    finalFrame.addByte(format & 0xFF);
    
    finalFrame.add(headerAndInfo);
    
    // FCS calculation (on all bytes between flags)
    final crcData = BytesBuilder();
    crcData.addByte((format >> 8) & 0xFF);
    crcData.addByte(format & 0xFF);
    crcData.add(headerAndInfo);
    final crc = Crc16.calculate(crcData.toBytes());
    
    finalFrame.addByte(crc & 0xFF);
    finalFrame.addByte((crc >> 8) & 0xFF);
    
    finalFrame.addByte(0x7E); // Flag
    
    return finalFrame.toBytes();
  }

  static void _writeAddress(BytesBuilder builder, int addr, int length) {
    // DLMS Addresses use bit 0 as "extension bit" (0 means more bytes, 1 means last)
    for (int i = 0; i < length; i++) {
      int byte = (addr >> (8 * (length - 1 - i))) & 0xFE;
      if (i == length - 1) byte |= 0x01; // Final byte
      builder.addByte(byte);
    }
  }

  /// Parses a raw HDLC frame.
  factory HdlcFrame.fromBytes(Uint8List bytes) {
    if (bytes[0] != 0x7E || bytes[bytes.length - 1] != 0x7E) {
      throw FormatException('Invalid HDLC frame flags');
    }
    
    // Verify CRC
    final frameData = bytes.sublist(1, bytes.length - 1);
    if (!Crc16.verify(frameData)) {
      throw FormatException('HDLC FCS Error');
    }
    
    // Minimal parser (assuming fixed 4+1 address for now)
    // Offset 0-1: Format
    // Offset 2-5: Dest Addr
    // Offset 6: Src Addr
    // Offset 7: Control
    // Offset 8...: Info
    
    return HdlcFrame(
      destAddress: 0, // Simplified
      srcAddress: 0,
      control: frameData[7],
      information: frameData.sublist(8, frameData.length - 2),
    );
  }
}
