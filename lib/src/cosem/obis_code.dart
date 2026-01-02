import 'dart:typed_data';

/// Represents a 6-byte OBIS Code (Object Identification System).
///
/// Immutable and optimized for hash map keys.
class ObisCode {
  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;

  const ObisCode(this.a, this.b, this.c, this.d, this.e, this.f);

  /// Creates an [ObisCode] from a dot-separated string (e.g., "1.0.1.8.0.255").
  factory ObisCode.fromString(String code) {
    final parts = code.split('.');
    if (parts.length != 6) {
      throw FormatException('Invalid OBIS code format: $code');
    }
    return ObisCode(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(parts[3]),
      int.parse(parts[4]),
      int.parse(parts[5]),
    );
  }

  /// Creates an [ObisCode] from a byte list.
  factory ObisCode.fromBytes(List<int> bytes) {
    if (bytes.length != 6) {
      throw FormatException('OBIS code must be exactly 6 bytes');
    }
    return ObisCode(bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]);
  }

  /// Converts the OBIS code to a [Uint8List].
  Uint8List toBytes() {
    return Uint8List.fromList([a, b, c, d, e, f]);
  }

  @override
  String toString() => '$a.$b.$c.$d.$e.$f';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObisCode &&
          a == other.a &&
          b == other.b &&
          c == other.c &&
          d == other.d &&
          e == other.e &&
          f == other.f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);
}
