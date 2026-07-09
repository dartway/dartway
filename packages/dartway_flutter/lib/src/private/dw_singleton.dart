import 'package:dartway_flutter/dartway_flutter.dart';

DwFlutter? _instance;

DwFlutter get dw {
  if (_instance == null) {
    throw StateError('Dw is not initialized');
  }
  return _instance!;
}

/// The instance when it exists — for framework code that may run before the
/// app core is initialized (e.g. the global error pipeline during bootstrap).
DwFlutter? get dwOrNull => _instance;

void setDwInstance(DwFlutter instance) {
  if (_instance != null) {
    throw StateError('Dw already initialized');
  }
  _instance = instance;
}
