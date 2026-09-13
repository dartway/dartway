import 'dart:io';

import 'package:path/path.dart' as p;

/// Locates the Dart SDK the analyzer reads `dart:` libraries from.
///
/// Under `dart run` the running executable is the SDK's own `dart`, which the
/// analyzer finds by itself. A compiled generator is its own executable and
/// has no SDK next to it, so the `dart` on `PATH` is followed instead —
/// through symlinks and through Flutter's wrapper script, whose SDK lives in
/// `bin/cache/dart-sdk`.
String? findDartSdk() {
  final running = Platform.resolvedExecutable;
  final fromRunning = _sdkAround(running);
  if (fromRunning != null) return fromRunning;

  final pathVariable = Platform.environment['PATH'] ?? '';
  final separator = Platform.isWindows ? ';' : ':';
  final names = Platform.isWindows ? ['dart.exe', 'dart.bat'] : ['dart'];
  for (final directory in pathVariable.split(separator)) {
    if (directory.isEmpty) continue;
    for (final name in names) {
      final candidate = File(p.join(directory, name));
      if (!candidate.existsSync()) continue;
      final sdk = _sdkAround(candidate.resolveSymbolicLinksSync());
      if (sdk != null) return sdk;
    }
  }
  return null;
}

String? _sdkAround(String executable) {
  final bin = p.dirname(executable);
  for (final candidate in [p.dirname(bin), p.join(bin, 'cache', 'dart-sdk')]) {
    if (_isSdk(candidate)) return candidate;
  }
  return null;
}

bool _isSdk(String directory) =>
    File(p.join(directory, 'version')).existsSync() &&
    Directory(p.join(directory, 'lib', '_internal')).existsSync();
