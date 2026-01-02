import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

/// A highly optimized A-XDR (XML Encoding Rules) Writer for DLMS.
///
/// Manages an internal buffer that expands automatically.
class AxdrWriter {
  Uint8List _buffer;
  ByteData _view;
  int _offset = 0;

  /// Creates a writer with an initial capacity (default 256 bytes).
  AxdrWriter({int initialCapacity = 256})
      : _buffer = Uint8List(initialCapacity),
        _view = ByteData(0) {
    _view = ByteData.view(_buffer.buffer);
  }

  /// Returns the bytes written so far as a new [Uint8List].
  Uint8List toBytes() {
    return _buffer.sublist(0, _offset);
  }

  void writeNull() {
    _ensureCapacity(1);
    _view.setUint8(_offset, 0x00);
    _offset += 1;
  }

  void writeBoolean(bool value) {
    _ensureCapacity(1);
    // DLMS Blue Book: Boolean is an OCTET. 0x00 is false, 0xFF is true (often). 
    // However, 0x01 is also common in implementations. 
    // We will stick to 0x01 for TRUE to be safe with most parsers, 
    // but strict DLMS might prefer 0xFF. For now using 0x01.
    _view.setUint8(_offset, value ? 0x01 : 0x00);
    _offset += 1;
  }

  void writeUint8(int value) {
    _ensureCapacity(1);
    _view.setUint8(_offset, value);
    _offset += 1;
  }

  void writeInt8(int value) {
    _ensureCapacity(1);
    _view.setInt8(_offset, value);
    _offset += 1;
  }

  void writeUint16(int value) {
    _ensureCapacity(2);
    _view.setUint16(_offset, value);
    _offset += 2;
  }

  void writeInt16(int value) {
    _ensureCapacity(2);
    _view.setInt16(_offset, value);
    _offset += 2;
  }

  void writeUint32(int value) {
    _ensureCapacity(4);
    _view.setUint32(_offset, value);
    _offset += 4;
  }

  void writeInt32(int value) {
    _ensureCapacity(4);
    _view.setInt32(_offset, value);
    _offset += 4;
  }

  void writeUint64(int value) {
    _ensureCapacity(8);
    _view.setUint64(_offset, value);
    _offset += 8;
  }

  void writeInt64(int value) {
    _ensureCapacity(8);
    _view.setInt64(_offset, value);
    _offset += 8;
  }

  void writeOctetString(List<int> value) {
    writeLength(value.length);
    _ensureCapacity(value.length);
    // Fast block copy
    _buffer.setRange(_offset, _offset + value.length, value);
    _offset += value.length;
  }

  void writeVisibleString(String value) {
    // VisibleString is ASCII. 
    // Ensure we encode only valid chars or just get bytes.
    final bytes = ascii.encode(value);
    writeOctetString(bytes);
  }

  /// Writes the variable length indicator.
  void writeLength(int length) {
    if (length < 0x80) {
      writeUint8(length);
    } else {
      // Logic for multi-byte length not fully implemented for > 0x7F in this minimal snippet
      // but following the pattern: 0x80 | num_bytes, then bytes MSB first.
      // For simplicity in Phase 1, we assume length < 128 or implement basic support:
      if (length <= 0xFF) {
        writeUint8(0x81); // 1 byte follows
        writeUint8(length);
      } else if (length <= 0xFFFF) {
        writeUint8(0x82); // 2 bytes follow
        writeUint16(length);
      } else {
        // ... support larger lengths
        writeUint8(0x84);
        writeUint32(length);
      }
    }
  }

  /// Ensures the internal buffer has enough space for [count] additional bytes.
  void _ensureCapacity(int count) {
    if (_offset + count <= _buffer.length) return;

    int newSize = max(_buffer.length * 2, _offset + count);
    final newBuffer = Uint8List(newSize);
    newBuffer.setRange(0, _offset, _buffer);
    _buffer = newBuffer;
    _view = ByteData.view(_buffer.buffer);
  }
}
