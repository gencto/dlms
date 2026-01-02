import 'dart:typed_data';
import '../encoding/axdr_reader.dart';
import '../cosem/dlms_value.dart';
import '../cosem/obis_code.dart';

/// Represents an Event Notification Request (Tag 0xC2).
///
/// This is an unconfirmed push message from the meter.
class EventNotificationRequestPdu {
  final DateTime? time;
  final int classId;
  final ObisCode instanceId;
  final int attributeId;
  final DlmsValue? value;

  EventNotificationRequestPdu({
    this.time,
    required this.classId,
    required this.instanceId,
    required this.attributeId,
    this.value,
  });

  factory EventNotificationRequestPdu.fromBytes(Uint8List data) {
    final reader = AxdrReader(data);
    final tag = reader.readUint8();
    if (tag != 0xC2) {
      throw FormatException('Invalid EventNotification tag: $tag');
    }

    // Time (Optional) - presence usually implied or length based?
    // Standard:
    // time [0] OPTIONAL OctetString (12)
    // cosem-attribute-descriptor
    // attribute-value

    // Simplistic parser assuming time is usually NOT present or we rely on standard profile
    // Actually, A-XDR OPTIONAL usually has 0x01/0x00 prefix.

    // Let's assume standard structure:
    // [Length of Time]? No.
    // Let's try to read byte. If it looks like a Cosem DateTime length (12) or null (0)?
    // A-XDR rules: OPTIONAL = Boolean (1=present).

    final hasTime = reader.readUint8();
    if (hasTime == 0x01) {
      reader.readOctetString();
      // Parse DT... (Reuse logic from CosemClock?)
      // For now, skip parsing DT to keep it simple or implement later.
    }

    final classId = reader.readUint16();
    final obis = ObisCode.fromBytes(reader.readOctetString());
    final attrId = reader.readInt8();

    final val = DlmsValue.decode(reader);

    return EventNotificationRequestPdu(
      classId: classId,
      instanceId: obis,
      attributeId: attrId,
      value: val,
    );
  }
}
