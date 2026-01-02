import 'dart:typed_data';

/// Abstract base class for High Level Security (HLS) mechanisms.
/// 
/// Implementations (e.g., GMAC, SHA256) must provide the logic for
/// challenge generation, verification, and response calculation.
abstract class HlsMechanism {
  /// The OID of the mechanism (e.g., id-mechanism-name-5 for GMAC).
  List<int> get mechanismName;

  /// The Authentication Key (AK) / Password.
  final Uint8List authenticationKey;
  
  /// The Encryption Key (EK) - Required for GMAC.
  final Uint8List? encryptionKey;

  HlsMechanism(this.authenticationKey, {this.encryptionKey});

  /// Generates the Client-to-Server (CtoS) challenge.
  /// 
  /// Usually a random 8-16 byte OctetString.
  Uint8List generateChallenge();

  /// Verifies the Server-to-Client (StoC) challenge received in AARE.
  /// 
  /// Returns true if valid. Throws Exception if verification fails.
  bool verifyServerChallenge(Uint8List serverChallenge);

  /// Calculates the response to be sent in the ActionRequest (Pass 4).
  /// 
  /// [serverChallenge] is the raw StoC challenge received from the meter.
  /// [clientChallenge] is the CtoS challenge we sent earlier.
  Uint8List calculateResponse(Uint8List serverChallenge, Uint8List clientChallenge);
}
