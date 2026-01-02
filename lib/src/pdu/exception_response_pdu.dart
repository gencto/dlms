import 'dart:typed_data';
import '../encoding/axdr_reader.dart';

/// Represents a DLMS Exception Response (Tag 0xD8).
class ExceptionResponsePdu {
  final int stateError;
  final int serviceError;

  ExceptionResponsePdu({required this.stateError, required this.serviceError});

  factory ExceptionResponsePdu.fromBytes(Uint8List data) {
    final reader = AxdrReader(data);
    final tag = reader.readUint8();
    if (tag != 0xD8) {
      throw FormatException('Invalid ExceptionResponse tag: $tag');
    }
    
    final state = reader.readUint8();
    final service = reader.readUint8();
    
    return ExceptionResponsePdu(stateError: state, serviceError: service);
  }

  @override
  String toString() {
    return 'ExceptionResponse(state: $_stateString, service: $_serviceString)';
  }

  String get _stateString {
    switch (stateError) {
      case 0: return 'Service Allowed';
      case 1: return 'Service Not Allowed';
      case 2: return 'Other Reason';
      default: return 'Unknown($stateError)';
    }
  }

  String get _serviceString {
    switch (serviceError) {
      case 0: return 'Operation Not Possible';
      case 1: return 'Service Not Supported';
      case 2: return 'Other Reason';
      case 3: return 'PDU Too Long';
      case 4: return 'Deciphering Error';
      case 5: return 'Invocation Counter Error';
      case 6: return 'Block Number Error';
      default: return 'Unknown($serviceError)';
    }
  }
}
