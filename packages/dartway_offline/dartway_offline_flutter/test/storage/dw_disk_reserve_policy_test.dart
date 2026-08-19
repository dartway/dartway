import 'package:dartway_offline_flutter/src/storage/dw_disk_reserve_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDiskReservePolicy', () {
    test('allows exact equality and rejects one byte below it', () {
      final equalityDecision = DwDiskReservePolicy.evaluate(
        totalDiskBytes: BigInt.from(1001),
        freeDiskBytes: BigInt.from(301),
        bytesStillToWrite: BigInt.from(200),
      );
      final insufficientDecision = DwDiskReservePolicy.evaluate(
        totalDiskBytes: BigInt.from(1001),
        freeDiskBytes: BigInt.from(300),
        bytesStillToWrite: BigInt.from(200),
      );

      expect(equalityDecision.reserveBytes, BigInt.from(101));
      expect(equalityDecision.requiredFreeBytes, BigInt.from(301));
      expect(equalityDecision.isAllowed, isTrue);
      expect(insufficientDecision.isAllowed, isFalse);
      expect(insufficientDecision.missingBytes, BigInt.one);
    });

    test('keeps exact results beyond fixed-width integer ranges', () {
      final hugeTotal = BigInt.parse('86400000000000000000000000000000000001');
      final writeBytes = BigInt.parse('9000000000000000000000000000000000000');

      final decision = DwDiskReservePolicy.evaluate(
        totalDiskBytes: hugeTotal,
        freeDiskBytes: BigInt.zero,
        bytesStillToWrite: writeBytes,
      );

      expect(
        decision.reserveBytes,
        BigInt.parse('8640000000000000000000000000000000001'),
      );
      expect(
        decision.requiredFreeBytes,
        BigInt.parse('17640000000000000000000000000000000001'),
      );
    });

    test('negative disk inputs fail fast', () {
      for (final values in [
        (total: BigInt.from(-1), free: BigInt.zero, write: BigInt.zero),
        (total: BigInt.one, free: BigInt.from(-1), write: BigInt.zero),
        (total: BigInt.one, free: BigInt.zero, write: BigInt.from(-1)),
      ]) {
        expect(
          () => DwDiskReservePolicy.evaluate(
            totalDiskBytes: values.total,
            freeDiskBytes: values.free,
            bytesStillToWrite: values.write,
          ),
          throwsArgumentError,
        );
      }
    });
  });
}
