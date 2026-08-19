/// What the core ships for the tests written against it.
///
/// Import this from a test, never from application code:
///
/// ```dart
/// import 'package:dartway_serverpod_core_flutter/testing.dart';
/// ```
///
/// Two kinds of thing live here, and nothing else:
///
/// * **Conformance suites.** A contract whose dangerous half cannot be held by
///   the shape of its API is held by a suite instead — the implementation runs
///   the core's own tests and either passes them or does not.
/// * **Test doubles for the core's own seams.** `DwRecordingServerTransport`
///   stands in for the server, so a widget test can watch a feature save
///   without a Serverpod client anywhere in the process.
///
/// They ship from here rather than from the main barrel so that nothing an
/// application imports can reach them by accident.
library;

export 'src/testing/dw_recording_server_transport.dart';
export 'src/testing/dw_repo_local_reads_conformance.dart';
export 'src/testing/dw_repo_local_writes_conformance.dart';
