import 'dart:typed_data';
import '../encoding/axdr_writer.dart';
import '../cosem/obis_code.dart';
import '../cosem/access_selection.dart';

/// Represents a Cosem Attribute Descriptor (Class, Obis, Attr).
class CosemAttributeDescriptor {
  final int classId;
  final ObisCode instanceId;
  final int attributeId;

  const CosemAttributeDescriptor({
    required this.classId,
    required this.instanceId,
    required this.attributeId,
  });

  void encode(AxdrWriter writer) {
    writer.writeUint16(classId);
    writer.writeOctetString(instanceId.toBytes());
    writer.writeInt8(attributeId);
  }
}

/// Represents a Cosem Attribute Descriptor with Selection (Class, Obis, Attr, Selector).
class CosemAttributeDescriptorWithSelection {
  final CosemAttributeDescriptor descriptor;
  final AccessSelector? accessSelector;

  const CosemAttributeDescriptorWithSelection({
    required this.descriptor,
    this.accessSelector,
  });
  
  void encode(AxdrWriter writer) {
     descriptor.encode(writer);
     if (accessSelector == null) {
       writer.writeUint8(0x00);
     } else {
       writer.writeUint8(0x01);
       writer.writeUint8(accessSelector!.selector);
       accessSelector!.encode(writer);
     }
  }
}

/// Represents a Get-Request PDU (Tag 0xC0).
class GetRequestPdu {
  final int requestType;
  final int invokeIdAndPriority;
  
  // Normal (0x01) Fields
  final CosemAttributeDescriptorWithSelection? normalDescriptor;

  // Next (0x02) Fields
  final int? blockNumber;

  // WithList (0x03) Fields
  final List<CosemAttributeDescriptorWithSelection>? listDescriptors;
  
  GetRequestPdu.normal({
    this.invokeIdAndPriority = 0x81,
    required int classId,
    required ObisCode instanceId,
    required int attributeId,
    AccessSelector? accessSelector,
  }) : requestType = 0x01,
       blockNumber = null,
       listDescriptors = null,
       normalDescriptor = CosemAttributeDescriptorWithSelection(
         descriptor: CosemAttributeDescriptor(classId: classId, instanceId: instanceId, attributeId: attributeId),
         accessSelector: accessSelector,
       );

  GetRequestPdu.next({
    this.invokeIdAndPriority = 0x81,
    required int this.blockNumber,
  }) : requestType = 0x02,
       normalDescriptor = null,
       listDescriptors = null;

  GetRequestPdu.withList({
    this.invokeIdAndPriority = 0x81,
    required List<CosemAttributeDescriptorWithSelection> this.listDescriptors,
  }) : requestType = 0x03,
       normalDescriptor = null,
       blockNumber = null;

  Uint8List toBytes() {
    final writer = AxdrWriter();
    
    writer.writeUint8(0xC0); // GetRequest Tag
    writer.writeUint8(requestType);
    writer.writeUint8(invokeIdAndPriority);
    
    if (requestType == 0x01) { // Normal
       normalDescriptor!.encode(writer);
    } else if (requestType == 0x02) { // Next
       writer.writeUint32(blockNumber!);
    } else if (requestType == 0x03) { // WithList
       writer.writeLength(listDescriptors!.length);
       for (final desc in listDescriptors!) {
         desc.encode(writer);
       }
    }
    
    return writer.toBytes();
  }
}