import 'dart:async';

import 'dart:typed_data';
import 'cosem/dlms_value.dart';
import 'cosem/obis_code.dart';
import 'pdu/aare_pdu.dart';
import 'pdu/aarq_pdu.dart';
import 'pdu/get_request_pdu.dart';
import 'pdu/get_request_next_pdu.dart';
import 'pdu/get_response_pdu.dart';
import 'pdu/set_request_pdu.dart';
import 'pdu/set_response_pdu.dart';
import 'pdu/action_request_pdu.dart';
import 'pdu/action_response_pdu.dart';
import 'pdu/exception_response_pdu.dart';
import 'transport/dlms_transport.dart';
import 'encoding/axdr_reader.dart';
import 'cosem/access_selection.dart';

import 'security/hls_mechanism.dart';

/// High-level client for interacting with DLMS meters.
class DlmsClient {
  final DlmsTransport transport;
  bool _isConnected = false;

  DlmsClient(this.transport);

  bool get isConnected => _isConnected;

  /// Establishes a DLMS application association.
  ///
  /// [password] is used for LLS (Low Level Security).
  /// [hls] is used for HLS (High Level Security) 4-pass handshake.
  ///
  /// If [hls] is provided, [password] is ignored (or used inside the HLS mechanism).
  Future<bool> connect({String? password, HlsMechanism? hls}) async {
    await transport.connect();

    // Pass 1: Send AARQ
    Uint8List? cToS;
    List<int>? mechName;

    if (hls != null) {
      cToS = hls.generateChallenge();
      mechName = hls.mechanismName;
    }

    final aarq = AarqPdu(
      authenticationKey: password,
      callingAuthenticationValue: cToS,
      mechanismName: mechName,
    );

    final responseBytes = await transport.sendRequest(aarq.toBytes());
    final aare = AarePdu(responseBytes);

    if (!aare.isAccepted) {
      // Failed at Association level
      _isConnected = false;
      return false;
    }

    _isConnected = true;

    // If HLS, Perform Pass 3 & 4
    if (hls != null) {
      try {
        // Pass 2 was receiving AARE. Extract StoC.
        // AARE 'authentication-value' contains the StoC.
        // We need to parse it from AARE.
        // Currently AarePdu doesn't expose authenticationValue explicitly,
        // we need to update AarePdu to parse it.
        final sToC = aare.authenticationValue;
        if (sToC == null) {
          throw Exception(
            'HLS Error: Server did not return a challenge (StoC)',
          );
        }

        // Pass 3: Verify Server
        hls.verifyServerChallenge(sToC);

        // Pass 4: Send Reply
        final responseValue = hls.calculateResponse(sToC, cToS!);

        // Invoke Method 1 (Reply_to_HLS_authentication) on Association LN
        // Current Association LN is usually 0.0.40.0.0.255
        // But the AARQ context might define it differently.
        // Standard Association SN is 0.0.40.0.0.255 (Class 15).

        // We assume Association LN (Class 15) instance 0.0.40.0.0.255
        final assocObis = ObisCode(0, 0, 40, 0, 0, 255);

        // The data is usually:
        // action-request-normal -> method-invocation-parameters -> OctetString (the response)
        // or just the raw bytes?
        // Method 1 of Association LN takes "OctetString" as data.
        final params = DlmsValue(responseValue, 9); // OctetString

        await action(15, assocObis, 1, params: params);

        // Action returns success/fail. If action() didn't throw, we are good.
        // But wait, action() returns return-parameters. The RESULT is checked inside action().
      } catch (e) {
        _isConnected = false;
        await transport.disconnect();
        rethrow;
      }
    }

    return _isConnected;
  }

  /// Disconnects from the meter.
  Future<void> disconnect() async {
    await transport.disconnect();
    _isConnected = false;
  }

  /// Reads a COSEM attribute, automatically handling block transfers if necessary.
  Future<DlmsValue> read(
    int classId,
    ObisCode obis,
    int attributeId, {
    AccessSelector? selector,
  }) async {
    if (!_isConnected) throw StateError('Not connected to meter');

    final request = GetRequestPdu.normal(
      classId: classId,
      instanceId: obis,
      attributeId: attributeId,
      accessSelector: selector,
    );

    Uint8List responseBytes = await transport.sendRequest(request.toBytes());

    // Check for ExceptionResponse
    if (responseBytes.isNotEmpty && responseBytes[0] == 0xD8) {
      final ex = ExceptionResponsePdu.fromBytes(responseBytes);
      throw Exception('DLMS Exception: $ex');
    }

    GetResponsePdu response = GetResponsePdu.fromBytes(responseBytes);

    if (response.resultError != null) {
      throw Exception('DLMS Error: Data Access Result ${response.resultError}');
    }

    if (response is GetResponseWithBlock) {
      return _readAllBlocks(response);
    }

    return response.result!;
  }

  /// Reads multiple attributes in a single request (GetWithList).
  Future<List<DlmsValue>> readList(
    List<CosemAttributeDescriptorWithSelection> items,
  ) async {
    if (!_isConnected) throw StateError('Not connected to meter');

    final request = GetRequestPdu.withList(listDescriptors: items);

    Uint8List responseBytes = await transport.sendRequest(request.toBytes());
    GetResponsePdu response = GetResponsePdu.fromBytes(responseBytes);

    if (response.responseType != 0x03 || response.results == null) {
      throw Exception('Unexpected response type for readList');
    }

    return response.results!;
  }

  /// Handles multi-block reassembly.

  Future<DlmsValue> _readAllBlocks(GetResponseWithBlock firstBlock) async {
    final List<int> accumulatedData = List.from(firstBlock.rawData);
    bool isLast = firstBlock.lastBlock;
    int nextBlockNumber = firstBlock.blockNumber + 1;

    while (!isLast) {
      final nextRequest = GetRequestNextPdu(blockNumber: nextBlockNumber);
      final responseBytes = await transport.sendRequest(nextRequest.toBytes());
      final response = GetResponsePdu.fromBytes(responseBytes);

      if (response.resultError != null) {
        throw Exception('DLMS Block Error: ${response.resultError}');
      }

      if (response is! GetResponseWithBlock) {
        throw Exception('Expected block response but received something else');
      }

      accumulatedData.addAll(response.rawData);
      isLast = response.lastBlock;
      nextBlockNumber++;
    }

    // After reassembling all blocks, the data is usually the A-XDR encoded DlmsValue.
    final fullReader = AxdrReader(Uint8List.fromList(accumulatedData));
    return DlmsValue.decode(fullReader);
  }

  /// Writes a COSEM attribute.
  Future<void> write(
    int classId,
    ObisCode obis,
    int attributeId,
    DlmsValue value,
  ) async {
    if (!_isConnected) throw StateError('Not connected to meter');

    final request = SetRequestPdu.normal(
      classId: classId,
      instanceId: obis,
      attributeId: attributeId,
      value: value,
    );

    final responseBytes = await transport.sendRequest(request.toBytes());
    final response = SetResponsePdu.fromBytes(responseBytes);

    if (response.result != 0) {
      throw Exception('DLMS Set Error: Result Code ${response.result}');
    }
  }

  /// Writes multiple attributes in a single request (SetWithList).
  Future<List<int>> writeList(
    List<CosemAttributeDescriptorWithSelection> items,
    List<DlmsValue> values,
  ) async {
    if (!_isConnected) throw StateError('Not connected to meter');

    final request = SetRequestPdu.withList(
      listDescriptors: items,
      listValues: values,
    );

    final responseBytes = await transport.sendRequest(request.toBytes());
    final response = SetResponsePdu.fromBytes(responseBytes);

    if (response.responseType != 0x03 || response.results == null) {
      throw Exception('Unexpected response type for writeList');
    }

    return response.results!;
  }

  /// Invokes a COSEM method (Action).
  Future<DlmsValue?> action(
    int classId,
    ObisCode obis,
    int methodId, {
    DlmsValue? params,
  }) async {
    if (!_isConnected) throw StateError('Not connected to meter');

    final request = ActionRequestPdu(
      classId: classId,
      instanceId: obis,
      methodId: methodId,
      parameters: params,
    );

    final responseBytes = await transport.sendRequest(request.toBytes());
    final response = ActionResponsePdu.fromBytes(responseBytes);

    if (response.result != 0) {
      throw Exception('DLMS Action Error: Result Code ${response.result}');
    }

    return response.returnParameters;
  }
}
