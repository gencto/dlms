import 'dart:typed_data';
import '../encoding/axdr_reader.dart';

/// Represents a Set-Response PDU (Tag 0xC5).
class SetResponsePdu {
  final int responseType;
  final int invokeIdAndPriority;
  final int? result; // 0=Success, otherwise error code
  final List<int>? results; // For WithList

  SetResponsePdu({
    required this.responseType,
    required this.invokeIdAndPriority,
    this.result,
    this.results,
  });

  factory SetResponsePdu.fromBytes(Uint8List data) {
    final reader = AxdrReader(data);
    final tag = reader.readUint8();
    if (tag != 0xC5) {
      throw FormatException('Invalid SetResponse tag: $tag');
    }

    final responseType = reader.readUint8();
    final invokeId = reader.readUint8();
    
    if (responseType == 0x01) { // SetResponseNormal
       final result = reader.readUint8(); // Result code
       return SetResponsePdu(
         responseType: responseType,
         invokeIdAndPriority: invokeId,
         result: result,
       );
    } else if (responseType == 0x03) { // SetResponseWithList
       final count = _readLength(reader);
       final list = <int>[];
       for(int i=0; i<count; i++) {
         list.add(reader.readUint8());
       }
       return SetResponsePdu(
         responseType: responseType,
         invokeIdAndPriority: invokeId,
         results: list,
       );
    }
    
    throw UnimplementedError('SetResponse type $responseType not implemented');
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
