import 'package:dlms/dlms.dart';
import 'dart:typed_data';

class MockHlsMechanism implements HlsMechanism {
  @override
  List<int> get mechanismName => [0x60, 0x85, 0x74, 0x05, 0x08, 0x02, 0x05]; // GMAC OID

  @override
  Uint8List get authenticationKey => Uint8List.fromList([1, 2, 3, 4]);

  @override
  Uint8List? get encryptionKey => null;

  @override
  Uint8List generateChallenge() {
    return Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]); // CtoS
  }

  @override
  bool verifyServerChallenge(Uint8List serverChallenge) {
    // Accept any challenge for mock
    print('Verifying StoC: $serverChallenge');
    return true;
  }

  @override
  Uint8List calculateResponse(Uint8List serverChallenge, Uint8List clientChallenge) {
    // Dummy response: 0xFF 0xFF ...
    return Uint8List.fromList(List.filled(8, 0xFF));
  }
}
