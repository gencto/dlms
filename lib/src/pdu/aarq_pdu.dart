import 'dart:typed_data';

enum AuthenticationLevel {
  none,
  lowest, // LLS (Password)
  highLevel, // HLS (GMAC, SHA, etc.)
}

/// Represents an Application Association Request (AARQ).
///
/// Used to establish a connection with the meter.
class AarqPdu {
  final int maxPduSize;
  final String? authenticationKey; // For LLS
  final Uint8List? callingAuthenticationValue; // For HLS (CtoS Challenge)
  final List<int>? mechanismName; // OID for HLS

  AarqPdu({
    this.maxPduSize = 0xFFFF,
    this.authenticationKey,
    this.callingAuthenticationValue,
    this.mechanismName,
  });

  Uint8List toBytes() {
    final builder = BytesBuilder();

    // 1. Application Context Name (Tag A1)
    // Logical Name (LN) Referencing: 2.16.756.5.8.1.1 (60 85 74 05 08 01 01)
    // Short Name (SN) Referencing: 2.16.756.5.8.1.2 (60 85 74 05 08 01 02)
    // We default to LN for now.
    builder.add([
      0xA1,
      0x09,
      0x06,
      0x07,
      0x60,
      0x85,
      0x74,
      0x05,
      0x08,
      0x01,
      0x01,
    ]);

    // 2. ACSE Requirements (Optional - Tag 8A) - Not strictly needed for basic LN

    // 3. Mechanism Name (Tag 8B) - For HLS
    if (mechanismName != null) {
      builder.addByte(0x8B); // [11] IMPLICIT Mechanism-Name
      builder.addByte(mechanismName!.length);
      builder.add(mechanismName!);
    }

    // 4. Calling Authentication Value (Tag AC)
    // LLS: GraphicString (Password)
    // HLS: CtoS Challenge (OctetString?)
    if (authenticationKey != null) {
      // LLS (Password)
      builder.addByte(0xAC); // Tag AC
      // Length of inner
      final passBytes = authenticationKey!.codeUnits;
      final innerLen = 2 + passBytes.length; // 80 len bytes

      builder.addByte(innerLen);
      builder.addByte(0x80); // GraphicString
      builder.addByte(passBytes.length);
      builder.add(passBytes);
    } else if (callingAuthenticationValue != null) {
      // HLS (Challenge)
      // AC [Length]
      //   A0 [Length] (Context 0)
      //     04 [Length] (OctetString)
      //       [Challenge Bytes]

      builder.addByte(0xAC);
      final challengeBytes = callingAuthenticationValue!;
      final octetStringLen = 2 + challengeBytes.length;
      final contextLen = 2 + octetStringLen;

      builder.addByte(contextLen);
      builder.addByte(0xA0); // Context 0
      builder.addByte(octetStringLen);
      builder.addByte(0x04); // OctetString
      builder.addByte(challengeBytes.length);
      builder.add(challengeBytes);
    }

    // 5. User Information (Tag BE) -> xDLMS InitiateRequest
    // ...

    // We construct the xDLMS InitiateRequest blob first
    final xdlmsPdu = BytesBuilder();
    xdlmsPdu.addByte(0x01); // Tag: InitiateRequest
    xdlmsPdu.addByte(0x00); // Dedicated Key (None)
    xdlmsPdu.addByte(0x00); // Response Allowed (False)
    xdlmsPdu.addByte(0x00); // Proposed Quality of Service (None)
    xdlmsPdu.addByte(0x06); // DLMS Version (6)

    // Conformance Block (Tag 5F 1F) - Standard set
    xdlmsPdu.add([
      0x5F,
      0x1F,
      0x04,
      0x00,
      0x00,
      0x7E,
      0x1F,
    ]); // Generic conformance

    // Max PDU Size (Tag 00?? No, Implicit U16)
    // Client Max PDU Size (U16)
    xdlmsPdu.addByte((maxPduSize >> 8) & 0xFF);
    xdlmsPdu.addByte(maxPduSize & 0xFF);

    final xdlmsBytes = xdlmsPdu.toBytes();

    // Wrap xDLMS in User Info (BE) -> Octet String (04)
    builder.addByte(0xBE);
    builder.addByte(2 + xdlmsBytes.length);
    builder.addByte(0x04);
    builder.addByte(xdlmsBytes.length);
    builder.add(xdlmsBytes);

    // Final AARQ (Tag 60)
    final content = builder.toBytes();
    final aarqBuilder = BytesBuilder();
    aarqBuilder.addByte(0x60);
    // Write length
    _writeLength(aarqBuilder, content.length);
    aarqBuilder.add(content);

    return aarqBuilder.toBytes();
  }

  void _writeLength(BytesBuilder b, int len) {
    if (len < 128) {
      b.addByte(len);
    } else {
      if (len < 256) {
        b.addByte(0x81);
        b.addByte(len);
      } else {
        b.addByte(0x82);
        b.addByte((len >> 8) & 0xFF);
        b.addByte(len & 0xFF);
      }
    }
  }
}
