import 'dart:io';

/// A durable reader pin paired with an open blob resource.
final class DwOfflineReaderHandle {
  DwOfflineReaderHandle.internal({
    required RandomAccessFile randomAccessFile,
    required Future<void> Function() releasePin,
  }) : _randomAccessFile = randomAccessFile,
       _releasePin = releasePin;

  final RandomAccessFile _randomAccessFile;
  final Future<void> Function() _releasePin;
  Future<void>? _closeFuture;

  Future<List<int>> read(int byteCount) => _randomAccessFile.read(byteCount);

  Future<int> length() => _randomAccessFile.length();

  Future<void> setPosition(int position) =>
      _randomAccessFile.setPosition(position);

  /// Closes the OS resource before releasing the persistent database pin.
  Future<void> close() => _closeFuture ??= _closeOnce();

  Future<void> _closeOnce() async {
    await _randomAccessFile.close();
    await _releasePin();
  }
}
