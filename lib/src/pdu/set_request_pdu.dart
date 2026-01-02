import 'dart:typed_data';
import '../encoding/axdr_writer.dart';
import '../cosem/obis_code.dart';
import '../cosem/dlms_value.dart';
import '../cosem/access_selection.dart';
import 'get_request_pdu.dart'; // For CosemAttributeDescriptorWithSelection

/// Represents a Set-Request PDU (Tag 0xC1).
class SetRequestPdu {
  final int requestType;
  final int invokeIdAndPriority;
  
  // Normal (0x01)
  final CosemAttributeDescriptorWithSelection? normalDescriptor;
  final DlmsValue? value;
  
  // WithList (0x03)
  final List<CosemAttributeDescriptorWithSelection>? listDescriptors;
  final List<DlmsValue>? listValues;

  SetRequestPdu.normal({
    this.invokeIdAndPriority = 0x81,
    required int classId,
    required ObisCode instanceId,
    required int attributeId,
    required DlmsValue this.value,
    AccessSelector? accessSelector,
  }) : requestType = 0x01,
       listDescriptors = null,
       listValues = null,
       normalDescriptor = CosemAttributeDescriptorWithSelection(
         descriptor: CosemAttributeDescriptor(classId: classId, instanceId: instanceId, attributeId: attributeId),
         accessSelector: accessSelector
       );

  SetRequestPdu.withList({
    this.invokeIdAndPriority = 0x81,
    required List<CosemAttributeDescriptorWithSelection> this.listDescriptors,
    required List<DlmsValue> this.listValues,
  }) : requestType = 0x03,
       normalDescriptor = null,
       value = null;

  Uint8List toBytes() {
    final writer = AxdrWriter();

    writer.writeUint8(0xC1); // SetRequest Tag
    writer.writeUint8(requestType);
    writer.writeUint8(invokeIdAndPriority);

    if (requestType == 0x01) {
       normalDescriptor!.encode(writer);
       value!.encode(writer);
    } else if (requestType == 0x03) {
       writer.writeLength(listDescriptors!.length);
       for (final desc in listDescriptors!) {
         desc.encode(writer);
       }
       writer.writeLength(listValues!.length);
       for (final val in listValues!) {
         val.encode(writer);
       }
    }
    
    return writer.toBytes();
  }
}