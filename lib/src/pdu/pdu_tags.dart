/// Common PDU Tags for xDLMS.
class PduTags {
  // Client -> Server
  static const int getRequest = 0xC0;
  static const int setRequest = 0xC1;
  static const int actionRequest = 0xC3;
  static const int methodRequest = 0xC3; // Same as action
  
  // Server -> Client
  static const int getResponse = 0xC4;
  static const int setResponse = 0xC5;
  static const int actionResponse = 0xC7;
  
  // Association
  static const int aarq = 0x60; // Application Association Request (ACSE tag, not xDLMS)
  static const int aare = 0x61; // Application Association Response
  static const int rlrq = 0x62; // Release Request
  static const int rlre = 0x63; // Release Response
}

/// Service definitions for GetRequest
class GetRequestTags {
  static const int normal = 0x01;
  static const int next = 0x02;
  static const int withList = 0x03;
}
