import '../dlms_client.dart';
import 'obis_code.dart';
import 'dlms_value.dart';
import 'cosem_object.dart';
import 'access_selection.dart';

/// Represents a COSEM Profile Generic object (Class ID 7).
class CosemProfileGeneric extends CosemObject {
  CosemProfileGeneric(DlmsClient client, ObisCode obis) : super(client, obis, 7);

  /// Reads the buffer (Attribute 2).
  /// 
  /// Optionally accepts a [range] to read only specific entries.
  Future<List<List<dynamic>>> getBuffer({RangeDescriptor? range}) async {
    final val = await client.read(classId, obis, 2, selector: range);
    
    // Result should be an Array (1) of Structures (2)
    if (val.type != 1) {
      throw FormatException('Profile buffer must be an Array');
    }
    
    final rows = <List<dynamic>>[];
    final rawRows = val.value as List<DlmsValue>;
    
    for (final rowItem in rawRows) {
      if (rowItem.type == 2) { // Structure
         final columns = rowItem.value as List<DlmsValue>;
         rows.add(columns.map((e) => e.value).toList());
      }
    }
    
    return rows;
  }

  /// Capture Objects (Attribute 3).
  Future<List<dynamic>> get captureObjects async {
    final val = await readAttribute(3);
    // Returns Array of Structures { classId, obis, attrId, dataIndex }
    return val.value; 
  }
}
