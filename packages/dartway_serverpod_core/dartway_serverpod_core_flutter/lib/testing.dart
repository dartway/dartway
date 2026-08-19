/// Test suites the core ships for the contracts it defines.
///
/// Import this from a test, never from application code:
///
/// ```dart
/// import 'package:dartway_serverpod_core_flutter/testing.dart';
/// ```
///
/// A contract whose dangerous half cannot be held by the shape of its API is
/// held by a suite instead — the implementation runs the core's own tests and
/// either passes them or does not.
library;

export 'src/testing/dw_repo_local_writes_conformance.dart';
