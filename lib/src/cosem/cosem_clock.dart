import '../dlms_client.dart';
import 'obis_code.dart';
import 'dlms_value.dart';
import 'cosem_object.dart';

/// Represents a COSEM Clock object (Class ID 8).
class CosemClock extends CosemObject {
  CosemClock(DlmsClient client, ObisCode obis) : super(client, obis, 8);

  /// Reads the current time (Attribute 2).
  Future<DateTime> get time async {
    final val = await readAttribute(2);
    // Value is usually OctetString (12 bytes) or Structure.
    // Need to parse CosemDateTime.
    if (val.type == 9) {
      return _parseCosemDateTime(val.value as List<int>);
    }
    throw FormatException('Invalid Clock Data Type: ${val.type}');
  }

  /// Sets the time (Attribute 2).
  Future<void> setTime(DateTime time) async {
    // Encode DateTime to 12 bytes OctetString
    final bytes = _toCosemDateTime(time);
    await writeAttribute(2, DlmsValue(bytes, 9));
  }

  /// Helper: Parse 12-byte Cosem DateTime
  DateTime _parseCosemDateTime(List<int> bytes) {
    // Format: Year(2), Month(1), Day(1), DayOfWeek(1), Hour(1), Min(1), Sec(1), Hundredths(1), Deviation(2), Status(1)
    if (bytes.length < 12) return DateTime.now(); // Fallback
    
    int year = (bytes[0] << 8) | bytes[1];
    int month = bytes[2];
    int day = bytes[3];
    // bytes[4] is DayOfWeek
    int hour = bytes[5];
    int minute = bytes[6];
    int second = bytes[7];
    // bytes[8] is Hundredths
    // bytes[9,10] is Deviation
    // bytes[11] is Status
    
    return DateTime(year, month, day, hour, minute, second);
  }

  List<int> _toCosemDateTime(DateTime dt) {
    final b = <int>[];
    b.add((dt.year >> 8) & 0xFF);
    b.add(dt.year & 0xFF);
    b.add(dt.month);
    b.add(dt.day);
    b.add(dt.weekday == 7 ? 0 : dt.weekday); // 1=Mon, 7=Sun (Dart) vs DLMS usually 1=Mon, 7=Sun. 0 is unspecified?
    b.add(dt.hour);
    b.add(dt.minute);
    b.add(dt.second);
    b.add(0); // Hundredths
    b.add(0x80); // Deviation High (0x8000 = unspecified)
    b.add(0x00); // Deviation Low
    b.add(0); // Status
    return b;
  }
}
