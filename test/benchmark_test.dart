import 'package:dlms/dlms.dart';
import 'package:test/test.dart';

void main() {
  test('Benchmark: A-XDR Encoding', () {
    final writer = AxdrWriter(initialCapacity: 1024);
    final stopwatch = Stopwatch()..start();

    const int iterations = 100000;

    for (int i = 0; i < iterations; i++) {
      writer.writeUint16(i);
      writer.writeBoolean(true);
      writer.writeOctetString([1, 2, 3, 4]);
    }

    stopwatch.stop();
    print(
      'A-XDR Encoding: ${stopwatch.elapsedMilliseconds} ms for $iterations iterations',
    );
    print(
      'Throughput: ${(iterations / stopwatch.elapsedMilliseconds * 1000).toStringAsFixed(0)} ops/sec',
    );

    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(2000),
      reason: 'Encoding should be fast',
    );
  });

  test('Benchmark: A-XDR Decoding', () {
    final writer = AxdrWriter(initialCapacity: 1024 * 1024);
    const int iterations = 100000;
    for (int i = 0; i < iterations; i++) {
      writer.writeUint32(i);
    }
    final bytes = writer.toBytes();

    final reader = AxdrReader(bytes);
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < iterations; i++) {
      reader.readUint32();
    }

    stopwatch.stop();
    print(
      'A-XDR Decoding: ${stopwatch.elapsedMilliseconds} ms for $iterations iterations',
    );
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
  });
}
