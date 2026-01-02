import 'dart:typed_data';
import '../encoding/axdr_reader.dart';
import '../cosem/dlms_value.dart';

/// Represents a Get-Response PDU (Tag 0xC4).
class GetResponsePdu {
  final int responseType;
  final int invokeIdAndPriority;
  final DlmsValue? result;
  final int? resultError;
  final List<DlmsValue>? results; // For WithList

  GetResponsePdu({
    required this.responseType,
    required this.invokeIdAndPriority,
    this.result,
    this.resultError,
    this.results,
  });

  factory GetResponsePdu.fromBytes(Uint8List data) {
    final reader = AxdrReader(data);

    final tag = reader.readUint8();
    if (tag != 0xC4) {
      throw FormatException('Invalid GetResponse tag: $tag');
    }

    final responseType = reader.readUint8();
    final invokeId = reader.readUint8();

    if (responseType == 0x01) {
      // GetResponseNormal
      final resultChoice = reader.readUint8();
      if (resultChoice == 0x00) {
        // data
        return GetResponsePdu(
          responseType: responseType,
          invokeIdAndPriority: invokeId,
          result: DlmsValue.decode(reader),
        );
      } else {
        // data-access-result (enum)
        return GetResponsePdu(
          responseType: responseType,
          invokeIdAndPriority: invokeId,
          resultError: reader.readUint8(),
        );
      }
    } else if (responseType == 0x02) {
      // GetResponseWithDataBlock
      final lastBlock = reader.readUint8() != 0;
      final blockNumber = reader.readUint32();
      final resultChoice = reader.readUint8();

      if (resultChoice == 0x00) {
        // raw-data
        final rawData = reader.readOctetString();
        return GetResponseWithBlock(
          responseType: responseType,
          invokeIdAndPriority: invokeId,
          lastBlock: lastBlock,
          blockNumber: blockNumber,
          rawData: rawData,
        );
      } else {
        return GetResponsePdu(
          responseType: responseType,
          invokeIdAndPriority: invokeId,
          resultError: reader.readUint8(),
        );
      }
    } else if (responseType == 0x03) {
      // GetResponseWithList
      final count = _readLength(reader);
      final list = <DlmsValue>[];
      for (var i = 0; i < count; i++) {
        final choice = reader.readUint8();
        if (choice == 0) {
          // Data
          list.add(DlmsValue.decode(reader));
        } else {
          // Access Result
          // We wrap errors in a special DlmsValue type or null?
          // Let's use a convention: Type -1 is error.
          list.add(DlmsValue(reader.readUint8(), -1));
        }
      }
      return GetResponsePdu(
        responseType: responseType,
        invokeIdAndPriority: invokeId,
        results: list,
      );
    }

    throw UnimplementedError('GetResponse type $responseType not implemented');
  }

  // Duplicate logic from DlmsValue, should move to Reader eventually
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

/// Specialized response for block transfers.
class GetResponseWithBlock extends GetResponsePdu {
  final bool lastBlock;
  final int blockNumber;
  final Uint8List rawData;

  GetResponseWithBlock({
    required super.responseType,
    required super.invokeIdAndPriority,
    required this.lastBlock,
    required this.blockNumber,
    required this.rawData,
  });
}
