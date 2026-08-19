final class DwDiskReserveDecision {
  const DwDiskReserveDecision({
    required this.isAllowed,
    required this.reserveBytes,
    required this.requiredFreeBytes,
    required this.observedFreeBytes,
    required this.missingBytes,
  });

  final bool isAllowed;
  final BigInt reserveBytes;
  final BigInt requiredFreeBytes;
  final BigInt observedFreeBytes;
  final BigInt missingBytes;
}

final class DwDiskReservePolicy {
  const DwDiskReservePolicy._();

  static DwDiskReserveDecision evaluate({
    required BigInt totalDiskBytes,
    required BigInt freeDiskBytes,
    required BigInt bytesStillToWrite,
  }) {
    _requireNonNegative(totalDiskBytes, 'totalDiskBytes');
    _requireNonNegative(freeDiskBytes, 'freeDiskBytes');
    _requireNonNegative(bytesStillToWrite, 'bytesStillToWrite');

    final reserveBytes = (totalDiskBytes + BigInt.from(9)) ~/ BigInt.from(10);
    final requiredFreeBytes = reserveBytes + bytesStillToWrite;
    final missingBytes = requiredFreeBytes > freeDiskBytes
        ? requiredFreeBytes - freeDiskBytes
        : BigInt.zero;
    return DwDiskReserveDecision(
      isAllowed: missingBytes == BigInt.zero,
      reserveBytes: reserveBytes,
      requiredFreeBytes: requiredFreeBytes,
      observedFreeBytes: freeDiskBytes,
      missingBytes: missingBytes,
    );
  }

  static void _requireNonNegative(BigInt byteCount, String parameterName) {
    if (byteCount.isNegative) {
      throw ArgumentError.value(
        byteCount,
        parameterName,
        'must not be negative.',
      );
    }
  }
}
