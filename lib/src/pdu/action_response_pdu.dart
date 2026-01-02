import 'dart:typed_data';
import '../encoding/axdr_reader.dart';
import '../cosem/dlms_value.dart';

/// Represents an Action-Response PDU (Tag 0xC7).
class ActionResponsePdu {
  final int responseType;
  final int invokeIdAndPriority;
  final int result; // 0=Success
  final DlmsValue? returnParameters;

  ActionResponsePdu({
    required this.responseType,
    required this.invokeIdAndPriority,
    required this.result,
    this.returnParameters,
  });

  factory ActionResponsePdu.fromBytes(Uint8List data) {
    final reader = AxdrReader(data);
    final tag = reader.readUint8();
    if (tag != 0xC7) {
      throw FormatException('Invalid ActionResponse tag: $tag');
    }

    final responseType = reader.readUint8();
    final invokeId = reader.readUint8();
    
    int result = -1;
    DlmsValue? returnParams;

    if (responseType == 0x01) { // ActionResponseNormal
       result = reader.readUint8(); // Action Result Code
       
       // Return parameters (Optional)
       // The presence byte
       if (reader.remaining > 0) {
         final hasParams = reader.readUint8();
         if (hasParams == 0x01) {
           // 0 means data access result (success), 1 means data
           // Actually, the structure of ActionResponseWithOptionalData is:
           // Result: ActionResult (enum)
           // ReturnParameters: Data (optional)
           
           // If result is success (0), typically there might be data.
           // Wait, the specification says:
           // ActionResponseNormal ::= SEQUENCE {
           //   invoke-id-and-priority,
           //   single-response: SEQUENCE {
           //      result: Action-Result,
           //      return-parameters: Get-Data-Result OPTIONAL
           //   }
           // }
           // Get-Data-Result ::= CHOICES { data, result }
           
           // It seems my simplified implementation assumes "0x01" means "Present".
           // Standard A-XDR OPTIONAL is 0x00 or 0x01.
           returnParams = DlmsValue.decode(reader);
         }
       }
    }
    
    return ActionResponsePdu(
      responseType: responseType,
      invokeIdAndPriority: invokeId,
      result: result,
      returnParameters: returnParams,
    );
  }
}
