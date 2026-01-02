# DLMS/COSEM Library for Dart

A robust, pure Dart implementation of the **DLMS/COSEM** protocol (IEC 62056), designed for reading smart meters (electricity, water, gas) and other IoT devices.

This library supports both **TCP/IP** and **HDLC (Serial/Optical)** transport layers, **High-Level Security (HLS)** foundations, and provides a strongly-typed API for common COSEM objects.

## Features

- **Transport Layers**: 
  - TCP/IP (IPv4/IPv6)
  - HDLC (Serial, Optical Probe) with SNRM/UA handshake and CRC-16.
- **Protocol Support**:
  - **GET**: Read attributes (Normal and Block Transfer for large data).
  - **SET**: Write attributes.
  - **ACTION**: Invoke methods (e.g., disconnect relay, capture profile).
  - **Selective Access**: Read specific ranges (e.g., date-based) from Load Profiles.
- **Security**:
  - Low Level Security (LLS - Password).
  - High Level Security (HLS) support (Challenge/Response mechanisms).
- **Interface Classes**:
  - `CosemClock` (Class 8) - DateTime management.
  - `CosemRegister` (Class 3) - Energy/Water values with scaler/units.
  - `CosemProfileGeneric` (Class 7) - Load profiles and event logs.
  - Extensible `CosemObject` base.
- **Encoding**: Highly optimized A-XDR (Xml Encoding Rules) reader/writer.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  dlms: ^1.0.0
```

## Usage

### 1. Connecting via TCP

```dart
import 'package:dlms/dlms.dart';

void main() async {
  // 1. Create Transport (TCP)
  final transport = TcpTransport('192.168.1.100', 4059);
  
  // 2. Create Client
  final client = DlmsClient(transport);
  
  try {
    // 3. Connect (LLS Password optional)
    await client.connect(password: '123456');
    print('Connected!');

    // 4. Read Active Energy (Register Class)
    // 1.0.1.8.0.255 = Active Energy Import (+A)
    final obis = ObisCode(1, 0, 1, 8, 0, 255);
    final register = CosemRegister(client, obis);
    
    print('Energy: ${await register.value} Wh');
    
  } finally {
    await client.disconnect();
  }
}
```

### 2. Reading Load Profile (Block Transfer & Selective Access)

The library automatically handles multi-block transfers for large files.

```dart
// Define the range (e.g., last 24 hours)
final range = RangeDescriptor(
  restrictedObject: const DlmsValue([], 2), // Columns definition
  fromValue: const DlmsValue('2023-01-01', 10), // Start Time
  toValue: const DlmsValue('2023-01-02', 10),   // End Time
  selectedValues: <DlmsValue>[], // All columns
);

final profile = CosemProfileGeneric(client, ObisCode(1, 0, 99, 1, 0, 255));

// Fetch buffer
final rows = await profile.getBuffer(range: range);

for (final row in rows) {
  print(row); // [DateTime, Energy, Voltage, ...]
}
```

### 3. Using HDLC (Serial)

To use HDLC, you need a stream of bytes (e.g., from `flutter_libserialport` or `dart_serial_port`).

```dart
// Hypothetical serial port stream
final serialStream = port.inputStream; 
final serialSink = port.write;

final transport = HdlcTransport(
  byteStream: serialStream,
  byteSink: serialSink,
  clientAddress: 0x21, // Public Client
  serverAddress: 0x03, // Logical Device Address (last 2 digits of Serial?)
);

```dart
final client = DlmsClient(transport);
await client.connect();
```

### 4. Controlling Disconnect Breaker (Class 70)

Safely manage the supply remotely.

```dart
final breaker = CosemDisconnectControl(
  client, 
  ObisCode(0, 0, 96, 3, 10, 255)
);

if (await breaker.outputState) {
  print('Breaker is CLOSED (Power ON). Disconnecting...');
  await breaker.remoteDisconnect();
} else {
  print('Breaker is OPEN (Power OFF). Reconnecting...');
  await breaker.remoteReconnect();
}
```

## Supported PDU Types

- **AARQ / AARE** (Association Request/Response)
- **GetRequest / GetResponse** (Normal, Next, WithBlock)
- **SetRequest / SetResponse**
- **ActionRequest / ActionResponse**

## Contributing

Contributions are welcome! Please open issues or submit PRs for:
- Additional Interface Classes (e.g., Data, RegisterMonitor).
- HLS Mechanisms (GMAC, SHA256 implementation).
- More robust Transport layers.