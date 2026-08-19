import 'package:dartway_flutter/dartway_flutter.dart';

DwFlutter? _instance;

DwFlutter get dw {
  if (_instance == null) {
    throw StateError(
      'Dw is not initialized.\n'
      'Make sure the app built its core — DwFlutter(config: ...), or the '
      'DwCore of a Serverpod app — before anything reached dw. A widget test '
      'has to boot one too: a feature reaches dw while building, not on the '
      'tap, so the subtree does not render without it.',
    );
  }
  return _instance!;
}

/// The instance when it exists — for framework code that may run before the
/// app core is initialized (e.g. the global error pipeline during bootstrap).
DwFlutter? get dwOrNull => _instance;

void setDwInstance(DwFlutter instance) {
  if (_instance != null) {
    throw StateError(
      'Dw is already initialized.\n'
      'One core per process, and it cannot be replaced. A test file that '
      'boots the core must do so through an initializer that is idempotent, '
      'so a second call is a no-op rather than this error.',
    );
  }
  _instance = instance;
}
