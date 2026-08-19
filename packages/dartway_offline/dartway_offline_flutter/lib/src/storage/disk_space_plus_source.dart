import 'package:disk_space_plus/disk_space_plus.dart';

final class DwDiskSpaceSnapshot {
  const DwDiskSpaceSnapshot({
    required this.freeBytes,
    required this.totalBytes,
  });

  final BigInt freeBytes;
  final BigInt totalBytes;
}

abstract interface class DwDiskSpaceSource {
  Future<DwDiskSpaceSnapshot> read();
}

typedef DwDiskSpaceMiBReader = Future<double?> Function();

final class DwDiskSpacePlusSource implements DwDiskSpaceSource {
  DwDiskSpacePlusSource({
    DwDiskSpaceMiBReader? readFreeMiB,
    DwDiskSpaceMiBReader? readTotalMiB,
  }) : _readFreeMiB = readFreeMiB ?? (() => DiskSpacePlus().getFreeDiskSpace),
       _readTotalMiB =
           readTotalMiB ?? (() => DiskSpacePlus().getTotalDiskSpace);

  static const int bytesPerMiB = 1024 * 1024;

  final DwDiskSpaceMiBReader _readFreeMiB;
  final DwDiskSpaceMiBReader _readTotalMiB;

  @override
  Future<DwDiskSpaceSnapshot> read() async {
    final readings = await Future.wait([_readFreeMiB(), _readTotalMiB()]);
    final freeMiB = readings[0];
    final totalMiB = readings[1];
    if (!_isValid(freeMiB) || !_isValid(totalMiB)) {
      throw StateError('Disk space is unavailable.');
    }
    return DwDiskSpaceSnapshot(
      freeBytes: BigInt.from((freeMiB! * bytesPerMiB).floor()),
      totalBytes: BigInt.from((totalMiB! * bytesPerMiB).ceil()),
    );
  }

  static bool _isValid(double? value) {
    return value != null && value.isFinite && value >= 0;
  }
}
