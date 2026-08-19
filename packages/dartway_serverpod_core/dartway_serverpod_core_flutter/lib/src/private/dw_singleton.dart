import 'package:dartway_serverpod_core_flutter/src/core/dw_core.dart';

DwCore? _instance;

DwCore get dw {
  final v = _instance;
  if (v == null) {
    throw StateError(
      'DwCore is not initialized.\n'
      'Make sure the app built its core — DwCore(config: ..., client: ...) — '
      'before anything reached dw. In a test, boot it from setUpAll through '
      "the app's own initializer, and pass transport: "
      'DwRecordingServerTransport(...) instead of a client.',
    );
  }
  return v;
}

void setDwInstance(DwCore instance) {
  if (_instance != null) {
    throw StateError(
      'DwCore is already initialized.\n'
      'One core per process, and it cannot be replaced. A test file that '
      'boots the core must do so through an initializer that is idempotent, '
      'so a second call is a no-op rather than this error.',
    );
  }
  _instance = instance;
}
