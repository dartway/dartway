import 'dart:io';

/// Run-owned names override per-file prefixes so the CLI can recover resources
/// after the test process has stopped, even when its teardown never ran.
String? testRunId([Map<String, String>? environment]) {
  final id = (environment ?? Platform.environment)['DW_TEST_RUN_ID'];
  if (id == null) return null;
  if (!RegExp(r'^[a-z0-9]{16}$').hasMatch(id)) {
    throw ArgumentError(
      'DW_TEST_RUN_ID must be 16 lower-case letters or digits',
    );
  }
  return id;
}
