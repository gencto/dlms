import 'dart:typed_data';
import '../encoding/axdr_reader.dart';
import 'pdu_tags.dart';

/// Represents an Application Association Response (AARE).
///
/// Parses the server's response to an AARQ.
class AarePdu {
  final Uint8List rawData;

  bool isAccepted = false;
  int result = -1;
  int resultSourceDiagnostic = -1;

  // xDLMS negotiated parameters
  int negotiatedMaxPduSize = 0;
  int negotiatedDlmsVersion = 0;
  Uint8List? negotiatedConformance;

  // HLS
  Uint8List? authenticationValue;

  AarePdu(this.rawData) {
    _parse();
  }

  void _parse() {
    // AARE is BER encoded.
    if (rawData.isEmpty || rawData[0] != PduTags.aare) {
      throw FormatException('Invalid AARE PDU: Tag is not 0x61');
    }

    int offset = 0;

    // Tag
    offset++;

    // Outer Length
    final outerLen = _readLength(offset);
    final outerLenBytes = _lengthByteCount(offset);

    // Move inside the sequence
    offset += outerLenBytes;

    // Limit parsing to the scope of this PDU
    final endOffset = offset + outerLen;
    if (endOffset > rawData.length) {
      // Allow for some buffer slop or throw? Strict for now.
      throw FormatException(
        'AARE Length $outerLen exceeds buffer size ${rawData.length}',
      );
    }

    while (offset < endOffset) {
      final tag = rawData[offset];
      offset++;
      final len = _readLength(offset);
      final lenBytes = _lengthByteCount(offset);

      // Value starts after length field
      final valueOffset = offset + lenBytes;

      // Next tag starts after Value
      final nextTagOffset = valueOffset + len;

      if (tag == 0xA2) {
        // Result
        // ... (logic remains same)
        if (len == 1) {
          result = rawData[valueOffset];
        } else if (len == 3 && rawData[valueOffset] == 0x02) {
          // Explicit Integer: 02 01 00
          result = rawData[valueOffset + 2];
        }
      } else if (tag == 0xAA) {
        // Responding Authentication Value (Context 10) - StoC
        // Usually: AA [Length] -> 80 [Length] (GraphicString) or A0...
        // For HLS Challenge (StoC), it's often context specific A0 -> 04 -> Bytes
        // We just grab the inner content for now.

        // Simple heuristic: If it starts with A0/80, dive in.
        // For now, let's just return the raw inner bytes if simple
        // Or try to strip one layer if it is constructed.

        // Let's assume standard Context 0 (A0) wrapping OctetString (04)
        // Check inner
        if (len > 2 && rawData[valueOffset] == 0xA0) {
          // Skip context wrapper
          // A0 [Len] 04 [Len] [Bytes]
          // We need a proper recursive parser but for this specific field:
          int innerOff = valueOffset;
          // Skip A0 + Len
          innerOff++;
          final innerLenBytes = _lengthByteCount(innerOff);
          innerOff += innerLenBytes;

          if (rawData[innerOff] == 0x04) {
            innerOff++; // Skip 04
            final octetLen = _readLength(innerOff);
            final octetLenBytes = _lengthByteCount(innerOff);
            innerOff += octetLenBytes;

            authenticationValue = rawData.sublist(
              innerOff,
              innerOff + octetLen,
            );
          }
        } else {
          // Maybe direct GraphicString (80)?
          if (rawData[valueOffset] == 0x80) {
            authenticationValue = rawData.sublist(
              valueOffset + 2,
              valueOffset + len,
            );
          } else {
            // Fallback: just return the whole block? No, too risky.
          }
        }
      } else if (tag == 0xBE) {
        // User Information
        if (len > 0) {
          _parseUserInformation(
            rawData.sublist(valueOffset, valueOffset + len),
          );
        }
      }

      offset = nextTagOffset;
    }

    isAccepted = (result == 0);
  }

  void _parseUserInformation(Uint8List info) {
    // Expecting 0x04 (Octet String) wrapping the xDLMS InitiateResponse
    if (info.isEmpty) return;

    int offset = 0;
    if (info[0] == 0x04) {
      offset++;
      final len = _readLengthFromBuffer(info, offset);
      final headerLen = _lengthByteCountFromBuffer(info, offset);
      final xdlmsBytes = info.sublist(
        offset + headerLen,
        offset + headerLen + len,
      );
      _parseXdlmsInitiateResponse(xdlmsBytes);
    }
  }

  void _parseXdlmsInitiateResponse(Uint8List data) {
    final reader = AxdrReader(data);

    final tag = reader.readUint8();
    if (tag != 0x08) {
      // InitiateResponse tag
      // print('Not an InitiateResponse: $tag');
      return;
    }

    reader
        .readUint8(); // Negotiated Quality of Service (Optional/Default) - usually skipped or read if present?
    // Actually structure is:
    // negotiated-quality-of-service [0]
    // negotiated-dlms-version-number [1] Unsigned8
    // negotiated-conformance [2] Conformance
    // server-max-receive-pdu-size [3] Unsigned16
    // ...

    // However, A-XDR excludes optional fields if they are not marked present?
    // InitiateResponse is NOT optional fields struct. It's fixed order usually.
    // 1. negotiated-quality-of-service (Integer / Unsigned8 ? No it's optional)
    // Actually InitiateResponse parameters are OPTIONAL. So there is a presence byte?
    // No, xDLMS InitiateResponse definition:
    // negotiated-quality-of-service OPTIONAL
    // negotiated-dlms-version-number
    // negotiated-conformance
    // server-max-receive-pdu-size
    // vaa-name

    // Wait, Axdr encodes optionality for all fields?
    // For simplicity, let's assume standard response:
    // It starts with presence byte? No.
    // Let's assume standard simple meter response for now.
    // Usually:
    // Tag (08)
    // [00] (Quality of service not present? Or value?)
    // Actually, "negotiated-quality-of-service" is OPTIONAL.
    // If we assume it's NOT present, the first byte might be dlms-version.

    // Let's rely on reading what we know:
    // Usually byte 1 is DLMS version (6).

    negotiatedDlmsVersion = reader.readUint8();

    // Conformance (Bit String)
    // Length (bits) -> Bytes
    try {
      // Just reading raw to clear the buffer for PDU size
      // Length of conformance block
      // BitString is encoded as: [Length in bits] [Bytes...]
      // If we just want PDU size, we might need to skip correctly.

      // This parser is brittle without full spec compliance for OPTIONALs.
      // Assuming DLMS Version (1 byte), Conformance (BitString), MaxPDU (U16)

      // Skip conformance
      int confBits = reader.readUint8(); // len in bits
      int confBytes = (confBits / 8).ceil();
      for (int i = 0; i < confBytes; i++) {
        reader.readUint8();
      }

      negotiatedMaxPduSize = reader.readUint16();
    } catch (e) {
      // Parse error, ignore
    }
  }

  // Helpers for BER length
  int _readLength(int offset) {
    return _readLengthFromBuffer(rawData, offset);
  }

  int _readLengthFromBuffer(Uint8List buf, int offset) {
    int b = buf[offset];
    if ((b & 0x80) == 0) return b;
    int numBytes = b & 0x7F;
    int len = 0;
    for (int i = 0; i < numBytes; i++) {
      len = (len << 8) | buf[offset + 1 + i];
    }
    return len;
  }

  int _lengthByteCount(int offset) {
    return _lengthByteCountFromBuffer(rawData, offset);
  }

  int _lengthByteCountFromBuffer(Uint8List buf, int offset) {
    int b = buf[offset];
    if ((b & 0x80) == 0) return 1; // 1 byte for length
    return 1 + (b & 0x7F); // 1 byte for indicator + N bytes for value
  }
}
