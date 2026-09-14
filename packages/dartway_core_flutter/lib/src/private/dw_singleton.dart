import 'package:dartway_core_flutter/dartway_core_flutter.dart';

/// The live core, for framework code that has no other way to reach it: an
/// `AsyncValue` extension rendering an error branch, the zone error handler.
///
/// It is the one process-wide pointer the package keeps, and it is bound to a
/// core's lifetime rather than to the process: a core claims it when built and
/// releases it in [DwFlutter.dispose], so a test can build, dispose and build
/// again as often as it likes. Two cores alive at once is still refused — the
/// framework code above could not tell which one it means.
DwFlutter? _instance;

DwFlutter get dw {
  final instance = _instance;
  if (instance == null) {
    throw StateError(
      'Dw is not initialized.\n'
      'Make sure the app built its core — DwFlutter(config: ...), or DwFlutterCore '
      'with the data layer — before anything reached dw. A widget test has to '
      'build one too (and dispose it in tearDown): a feature reaches dw while '
      'building, not on the tap, so the subtree does not render without it.',
    );
  }
  return instance;
}

/// The instance when it exists — for framework code that may run before the
/// app core is built or after it was disposed (the global error pipeline).
DwFlutter? get dwOrNull => _instance;

void attachDwInstance(DwFlutter instance) {
  final current = _instance;
  if (current != null && !identical(current, instance)) {
    throw StateError(
      'Another dw core is alive.\n'
      'One core at a time: dispose the previous one (await dw.dispose()) '
      'before building the next — in a test, from tearDown.',
    );
  }
  _instance = instance;
}

void detachDwInstance(DwFlutter instance) {
  if (identical(_instance, instance)) _instance = null;
}
