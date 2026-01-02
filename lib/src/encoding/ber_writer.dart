import 'dart:typed_data';

/// A minimal BER (Basic Encoding Rules) Writer for ACSE PDUs.
///
/// Unlike A-XDR, BER uses Tag-Length-Value (TLV) triplets for everything.
class BerWriter {
  final BytesBuilder _builder = BytesBuilder();

  Uint8List toBytes() => _builder.toBytes();

  /// Writes a TLV structure.
  void writeTlv(int tag, Uint8List value) {
    _builder.addByte(tag);
    writeLength(value.length);
    _builder.add(value);
  }

  /// Writes the length field (supports definitive short and long forms).
  void writeLength(int length) {
    if (length <= 0x7F) {
      _builder.addByte(length);
    } else {
      // Long form
      // Calculate number of bytes needed
      final lenBytes = <int>[];
      int l = length;
      while (l > 0) {
        lenBytes.insert(0, l & 0xFF);
        l >>= 8;
      }
      _builder.addByte(0x80 | lenBytes.length);
      _builder.add(lenBytes);
    }
  }

  void writeUint8(int value) => _builder.addByte(value);

  void writeBytes(List<int> bytes) => _builder.add(bytes);
}
