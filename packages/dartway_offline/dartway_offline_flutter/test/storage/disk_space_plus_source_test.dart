import 'package:dartway_offline_flutter/src/storage/disk_space_plus_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDiskSpacePlusSource', () {
    test('converts MiB conservatively into byte counts', () async {
      final source = DwDiskSpacePlusSource(
        readFreeMiB: () async => 1.25,
        readTotalMiB: () async => 10.0000001,
      );

      final snapshot = await source.read();

      expect(snapshot.freeBytes, BigInt.from(1310720));
      expect(snapshot.totalBytes, BigInt.from(10485761));
    });

    test('fails closed for missing or invalid plugin readings', () async {
      for (final value in <double?>[null, -1, double.nan, double.infinity]) {
        final source = DwDiskSpacePlusSource(
          readFreeMiB: () async => value,
          readTotalMiB: () async => 10,
        );
        await expectLater(source.read(), throwsStateError);
      }
    });
  });
}
