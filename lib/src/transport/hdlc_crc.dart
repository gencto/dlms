import 'dart:typed_data';

/// CRC-16 (CCITT/X.25) implementation for HDLC.
///
/// Uses the polynomial 0x1021 (X16 + X12 + X5 + 1) with initial 0xFFFF and XOR 0xFFFF.
class Crc16 {
  static const int _polynomial = 0x8408; // Reflected 0x1021

  static final Uint16List _table = _generateTable();

  static Uint16List _generateTable() {
    final table = Uint16List(256);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ _polynomial;
        } else {
          crc >>= 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Calculates the FCS (Frame Check Sequence) for the given bytes.
  static int calculate(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc = (crc >> 8) ^ _table[(crc ^ b) & 0xFF];
    }
    return crc ^ 0xFFFF;
  }

  /// Verifies the FCS of a frame (the last 2 bytes should match the calculated CRC).
  static bool verify(Uint8List frame) {
    if (frame.length < 2) return false;
    final data = frame.sublist(0, frame.length - 2);
    final receivedCrc = (frame[frame.length - 1] << 8) | frame[frame.length - 2];
    return calculate(data) == receivedCrc;
  }
}
