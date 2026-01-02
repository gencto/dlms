import 'dart:typed_data';
import '../encoding/axdr_writer.dart';
import '../cosem/obis_code.dart';
import '../cosem/dlms_value.dart';

/// Represents an Action-Request PDU (Tag 0xC3).
///
/// Used to invoke methods on COSEM objects.
class ActionRequestPdu {
  final int requestType;
  final int invokeIdAndPriority;
  final int classId;
  final ObisCode instanceId;
  final int methodId;
  final DlmsValue? parameters;

  ActionRequestPdu({
    this.requestType = 0x01, // ActionRequestNormal
    this.invokeIdAndPriority = 0x81, // High priority, ID 1
    required this.classId,
    required this.instanceId,
    required this.methodId,
    this.parameters,
  });

  Uint8List toBytes() {
    final writer = AxdrWriter();

    writer.writeUint8(0xC3); // ActionRequest Tag
    writer.writeUint8(requestType);

    if (requestType == 0x01) {
      writer.writeUint8(invokeIdAndPriority);
      
      // CosemMethodDescriptor
      writer.writeUint16(classId);
      writer.writeOctetString(instanceId.toBytes());
      writer.writeInt8(methodId);
      
      // MethodInvocationParameters (Optional)
      if (parameters == null) {
        writer.writeUint8(0x00); // Not present
      } else {
        writer.writeUint8(0x01); // Present
        parameters!.encode(writer);
      }
    }
    
    return writer.toBytes();
  }
}
