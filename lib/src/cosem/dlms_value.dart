import '../encoding/axdr_reader.dart';
import '../encoding/axdr_writer.dart';

/// Represents a value returned by a DLMS meter.
///
/// Maps DLMS/A-XDR types to Dart types.
class DlmsValue {
  final dynamic value;
  final int type;

  const DlmsValue(this.value, this.type);

  @override
  String toString() => 'DlmsValue(type: $type, value: $value)';

  /// Recursively encodes this [DlmsValue] using an [AxdrWriter].
  void encode(AxdrWriter writer) {
    writer.writeUint8(type);
    
    switch (type) {
      case 0: // null-data
        break;
      case 3: // boolean
        writer.writeBoolean(value as bool);
        break;
      case 5: // double-long (int32)
        writer.writeInt32(value as int);
        break;
      case 6: // double-long-unsigned (uint32)
        writer.writeUint32(value as int);
        break;
      case 9: // octet-string
        writer.writeOctetString(value as List<int>);
        break;
      case 10: // visible-string
        writer.writeVisibleString(value as String);
        break;
      case 15: // integer (int8)
        writer.writeInt8(value as int);
        break;
      case 16: // long (int16)
        writer.writeInt16(value as int);
        break;
      case 17: // unsigned (uint8)
        writer.writeUint8(value as int);
        break;
      case 18: // long-unsigned (uint16)
        writer.writeUint16(value as int);
        break;
      case 20: // long64 (int64)
        writer.writeInt64(value as int);
        break;
      case 21: // long64-unsigned (uint64)
        writer.writeUint64(value as int);
        break;
      case 22: // enumerate
        writer.writeUint8(value as int);
        break;
      case 1: // array
        final list = value as List<DlmsValue>;
        writer.writeLength(list.length);
        for (final item in list) {
          item.encode(writer);
        }
        break;
      case 2: // structure
        final list = value as List<DlmsValue>;
        writer.writeLength(list.length);
        for (final item in list) {
          item.encode(writer);
        }
        break;
      default:
        throw FormatException('Unsupported DLMS data type for encoding: $type');
    }
  }

  // Deprecated _writeLength removed, using AxdrWriter.writeLength

  /// Recursively decodes a [DlmsValue] from an [AxdrReader].
  static DlmsValue decode(AxdrReader reader) {
    final type = reader.readUint8();

    switch (type) {
      case 0: // null-data
        return const DlmsValue(null, 0);
      case 3: // boolean
        return DlmsValue(reader.readBoolean(), 3);
      case 5: // double-long (int32)
        return DlmsValue(reader.readInt32(), 5);
      case 6: // double-long-unsigned (uint32)
        return DlmsValue(reader.readUint32(), 6);
      case 9: // octet-string
        return DlmsValue(reader.readOctetString(), 9);
      case 10: // visible-string
        return DlmsValue(reader.readVisibleString(), 10);
      case 15: // integer (int8)
        return DlmsValue(reader.readInt8(), 15);
      case 16: // long (int16)
        return DlmsValue(reader.readInt16(), 16);
      case 17: // unsigned (uint8)
        return DlmsValue(reader.readUint8(), 17);
      case 18: // long-unsigned (uint16)
        return DlmsValue(reader.readUint16(), 18);
      case 20: // long64 (int64)
        return DlmsValue(reader.readInt64(), 20);
      case 21: // long64-unsigned (uint64)
        return DlmsValue(reader.readUint64(), 21);
      case 22: // enumerate
        return DlmsValue(reader.readUint8(), 22);

      case 1: // array
        final length = _readLength(reader);
        final list = <DlmsValue>[];
        for (var i = 0; i < length; i++) {
          list.add(decode(reader));
        }
        return DlmsValue(list, 1);

      case 2: // structure
        final length = _readLength(reader);
        final list = <DlmsValue>[];
        for (var i = 0; i < length; i++) {
          list.add(decode(reader));
        }
        return DlmsValue(list, 2);

      default:
        throw FormatException(
          'Unsupported DLMS data type: $type at offset ${reader.offset}',
        );
    }
  }

  static int _readLength(AxdrReader reader) {
    int len = reader.readUint8();
    if ((len & 0x80) != 0) {
      int numBytes = len & 0x7F;
      len = 0;
      for (int i = 0; i < numBytes; i++) {
        len = (len << 8) | reader.readUint8();
      }
    }
    return len;
  }
}
