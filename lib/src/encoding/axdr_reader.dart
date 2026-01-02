import 'dart:typed_data';
import 'dart:convert';

/// A highly optimized A-XDR (XML Encoding Rules) Reader for DLMS.
///
/// Uses [ByteData] view to read directly from the buffer without copying.
class AxdrReader {
  final ByteData _view;
  int _offset = 0;

  AxdrReader(Uint8List buffer) : _view = ByteData.sublistView(buffer);

  int get offset => _offset;
  int get remaining => _view.lengthInBytes - _offset;

  /// Reads a NULL value (tag 0x00).
  /// Throws if the next byte is not 0x00.
  void readNull() {
    if (readUint8() != 0x00) {
      throw FormatException('Expected Null (0x00) at offset ${_offset - 1}');
    }
  }

  /// Reads a Boolean (tag 0x03).
  bool readBoolean() {
    return readUint8() != 0x00;
  }

  /// Reads a generic uint8 (unsigned 8-bit integer).
  int readUint8() {
    _checkBounds(1);
    final value = _view.getUint8(_offset);
    _offset += 1;
    return value;
  }

  /// Reads a generic int8 (signed 8-bit integer).
  int readInt8() {
    _checkBounds(1);
    final value = _view.getInt8(_offset);
    _offset += 1;
    return value;
  }

  /// Reads a uint16 (unsigned 16-bit integer).
  int readUint16() {
    _checkBounds(2);
    final value = _view.getUint16(_offset);
    _offset += 2;
    return value;
  }

  /// Reads an int16 (signed 16-bit integer).
  int readInt16() {
    _checkBounds(2);
    final value = _view.getInt16(_offset);
    _offset += 2;
    return value;
  }

  /// Reads a uint32 (unsigned 32-bit integer).
  int readUint32() {
    _checkBounds(4);
    final value = _view.getUint32(_offset);
    _offset += 4;
    return value;
  }

  /// Reads an int32 (signed 32-bit integer).
  int readInt32() {
    _checkBounds(4);
    final value = _view.getInt32(_offset);
    _offset += 4;
    return value;
  }

  /// Reads a uint64 (unsigned 64-bit integer).
  int readUint64() {
    _checkBounds(8);
    final value = _view.getUint64(_offset);
    _offset += 8;
    return value;
  }

  /// Reads an int64 (signed 64-bit integer).
  int readInt64() {
    _checkBounds(8);
    final value = _view.getInt64(_offset);
    _offset += 8;
    return value;
  }

  /// Reads an OctetString (byte array) with length prefix.
  Uint8List readOctetString() {
    final length = _readLength();
    _checkBounds(length);
    // Create a copy to ensure ownership, or use sublistView for performance if immutability is guaranteed.
    // Here we use sublistView for max performance, assuming reader buffer isn't mutated externally.
    final bytes = Uint8List.view(_view.buffer, _view.offsetInBytes + _offset, length); 
    _offset += length;
    // We return a copy of the list to prevent external modification affecting the buffer,
    // or if the underlying buffer is reused. 
    // Ideally for pure speed we return the view, but safety usually dictates a copy for OctetStrings.
    return Uint8List.fromList(bytes); 
  }

  /// Reads a VisibleString (ASCII).
  String readVisibleString() {
    final bytes = readOctetString();
    // ASCII is a subset of UTF-8, generally safe to use utf8 decode for VisibleString
    // provided it falls within range.
    return utf8.decode(bytes);
  }

  /// Reads the variable length indicator used in DLMS.
  /// If the first byte < 0x80, it is the length.
  /// If >= 0x80, the lower 7 bits indicate how many subsequent bytes make up the length.
  int _readLength() {
    int len = readUint8();
    if ((len & 0x80) != 0) {
      int numBytes = len & 0x7F;
      len = 0;
      for (int i = 0; i < numBytes; i++) {
        len = (len << 8) | readUint8();
      }
    }
    return len;
  }

  void _checkBounds(int count) {
    if (_offset + count > _view.lengthInBytes) {
      throw RangeError('Not enough bytes to read. Needed $count, available $remaining');
    }
  }
}
