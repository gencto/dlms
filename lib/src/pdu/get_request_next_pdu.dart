import 'dart:typed_data';
import '../encoding/axdr_writer.dart';

/// Represents a Get-Request-Next PDU (Tag 0xC0, type 0x02).
///
/// Used to retrieve the next block in a multi-block transfer.
class GetRequestNextPdu {
  final int invokeIdAndPriority;
  final int blockNumber;

  GetRequestNextPdu({
    this.invokeIdAndPriority = 0x81,
    required this.blockNumber,
  });

  Uint8List toBytes() {
    final writer = AxdrWriter();
    
    writer.writeUint8(0xC0); // GetRequest Tag
    writer.writeUint8(0x02); // GetRequestNext
    writer.writeUint8(invokeIdAndPriority);
    writer.writeUint32(blockNumber);
    
    return writer.toBytes();
  }
}
