import '../dlms_client.dart';
import 'obis_code.dart';
import 'dlms_value.dart';
import 'cosem_object.dart';

/// Represents a COSEM Register object (Class ID 3).
class CosemRegister extends CosemObject {
  CosemRegister(DlmsClient client, ObisCode obis) : super(client, obis, 3);

  /// Reads the value (Attribute 2).
  Future<dynamic> get value async {
    final val = await readAttribute(2);
    return val.value;
  }

  /// Reads the scalar and unit (Attribute 3).
  /// Returns a record (scalar, unit).
  Future<({int scalar, int unit})> get scalerUnit async {
    final val = await readAttribute(3);
    if (val.type == 2) {
      // Structure
      final list = val.value as List<DlmsValue>;
      if (list.length >= 2) {
        return (scalar: list[0].value as int, unit: list[1].value as int);
      }
    }
    return (scalar: 0, unit: 0);
  }
}
