import '../encoding/axdr_writer.dart';
import 'dlms_value.dart';

/// Base class for Access Selection parameters.
abstract class AccessSelector {
  int get selector;
  void encode(AxdrWriter writer);
}

/// Selector 1: Range Descriptor (Access by range).
///
/// Used for reading specific ranges of a profile (e.g., by date).
class RangeDescriptor extends AccessSelector {
  final DlmsValue restrictedObject;
  final DlmsValue fromValue;
  final DlmsValue toValue;
  final List<DlmsValue> selectedValues;

  RangeDescriptor({
    required this.restrictedObject,
    required this.fromValue,
    required this.toValue,
    required this.selectedValues,
  });

  @override
  int get selector => 1;

  @override
  void encode(AxdrWriter writer) {
    // Structure:
    // restricted_object: CaptureObjectDefinition (Structure)
    // from_value: Data
    // to_value: Data
    // selected_values: Array of CaptureObjectDefinition

    // We wrap everything in a Structure for the AccessDescriptor
    // But the standard says AccessSelection parameters depend on the selector.
    // For Range (1): Sequence { ... }

    // Actually, A-XDR encoding of the SEQUENCE:
    restrictedObject.encode(writer);
    fromValue.encode(writer);
    toValue.encode(writer);

    // Encode Array of selected values
    // Manual array encoding to ensure correct structure
    if (selectedValues.isEmpty) {
      writer.writeUint8(0x01); // Array
      writer.writeUint8(0x00); // Length 0
    } else {
      // We assume the user passed a List<DlmsValue> that represents the array.
      // Let's just construct a DlmsValue(array) and encode it.
      final arrayVal = DlmsValue(selectedValues, 1);
      arrayVal.encode(writer);
    }
  }
}

/// Selector 2: Entry Descriptor (Access by entry index).
class EntryDescriptor extends AccessSelector {
  final int fromEntry;
  final int toEntry;
  final int fromSelectedValue;
  final int toSelectedValue;

  EntryDescriptor({
    required this.fromEntry,
    required this.toEntry,
    this.fromSelectedValue = 0,
    this.toSelectedValue = 0,
  });

  @override
  int get selector => 2;

  @override
  void encode(AxdrWriter writer) {
    // Structure { fromEntry, toEntry, fromSelected, toSelected }
    final struct = DlmsValue([
      DlmsValue(fromEntry, 6), // double-long-unsigned
      DlmsValue(toEntry, 6),
      DlmsValue(fromSelectedValue, 18), // long-unsigned
      DlmsValue(toSelectedValue, 18),
    ], 2); // Structure

    struct.encode(writer);
  }
}
