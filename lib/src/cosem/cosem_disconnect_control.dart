import '../dlms_client.dart';
import 'obis_code.dart';
import 'dlms_value.dart';
import 'cosem_object.dart';

/// Represents a COSEM Disconnect Control object (Class ID 70).
/// 
/// This interface allows for remote management of the supply control switch (breaker/relay).
/// 
/// Common OBIS Code: `0.0.96.3.10.255`.
/// 
/// **Safety Warning:** Operating the disconnect control can cut power to the premises. 
/// Ensure you have authorization and safety protocols in place before using `remoteDisconnect` 
/// or `remoteReconnect`.
class CosemDisconnectControl extends CosemObject {
  CosemDisconnectControl(DlmsClient client, ObisCode obis) : super(client, obis, 70);

  /// Reads the physical output state (Attribute 2).
  /// 
  /// * `true`: Connected (Switch is Closed). Power is ON.
  /// * `false`: Disconnected (Switch is Open). Power is OFF.
  Future<bool> get outputState async {
    final val = await readAttribute(2);
    // Attribute 2 is Boolean
    return val.value as bool;
  }

  /// Reads the internal control state (Attribute 3).
  /// 
  /// The control state indicates the internal logic status of the disconnect unit.
  /// 
  /// * `0`: Disconnected.
  /// * `1`: Connected.
  /// * `2`: Ready for Reconnection (Requires manual intervention/button press on meter).
  Future<int> get controlState async {
    final val = await readAttribute(3);
    // Attribute 3 is Enum (integer)
    return val.value as int;
  }

  /// Invokes the **Remote Disconnect** method (Method 1).
  /// 
  /// Sends a command to open the relay and cut power. 
  /// This operation usually requires High Level Security (HLS) authentication.
  Future<void> remoteDisconnect() async {
    // Method 1 takes integer parameter (0) usually.
    await invokeMethod(1, const DlmsValue(0, 15)); // 15 = Integer (int8)
  }

  /// Invokes the **Remote Reconnect** method (Method 2).
  /// 
  /// Sends a command to close the relay and restore power.
  /// 
  /// **Note:** Depending on the [controlState] and meter configuration, this might 
  /// only switch the meter to "Ready for Reconnection" state (2), requiring physical 
  /// user confirmation.
  Future<void> remoteReconnect() async {
    // Method 2 takes integer parameter (0).
    await invokeMethod(2, const DlmsValue(0, 15));
  }
}
