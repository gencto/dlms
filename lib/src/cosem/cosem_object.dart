import '../dlms_client.dart';
import 'obis_code.dart';
import 'dlms_value.dart';

/// Base class for all COSEM Interface Classes.
abstract class CosemObject {
  final DlmsClient client;
  final ObisCode obis;
  final int classId;

  CosemObject(this.client, this.obis, this.classId);

  /// Helper to read an attribute.
  Future<DlmsValue> readAttribute(int attributeId) {
    return client.read(classId, obis, attributeId);
  }

  /// Helper to write an attribute.
  Future<void> writeAttribute(int attributeId, DlmsValue value) {
    return client.write(classId, obis, attributeId, value);
  }

  /// Helper to invoke a method.
  Future<DlmsValue?> invokeMethod(int methodId, [DlmsValue? params]) {
    return client.action(classId, obis, methodId, params: params);
  }

  /// Logical Name (Attribute 1) is common to all.
  Future<String> get logicalName async {
    final val = await readAttribute(1);
    // Usually returns OctetString (6 bytes) of the OBIS code.
    // We can convert back to OBIS string if needed.
    if (val.type == 9) {
      // OctetString
      final bytes = val.value as List<int>;
      return ObisCode.fromBytes(bytes).toString();
    }
    return val.value.toString();
  }
}
