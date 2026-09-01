/// Why an integration suite has to say something before it starts.
///
/// `withServerpod` builds its `TestServerpod` inside
/// `IOOverrides.runZoned(stdout: NullStdOut())` — deliberately, so a passing
/// run is not buried in server chatter. The cost is that a server which fails
/// to start says so into the same silence. Run a suite with no database and the
/// entire output is:
///
/// ```
/// 00:00 +0: loading test/integration/app_setting_access_test.dart
/// ```
///
/// followed by exit code 1. No error, no exception, no mention of a database, a
/// host or a port — and the first thing anyone concludes from a silent exit 1
/// is that something is wrong with the test file, which is the one thing that
/// is fine.
///
/// The most common cause is fully knowable before the server starts, so this
/// checks for it there, where output still reaches a terminal.
library;

import 'dart:io';

import 'package:serverpod_test/serverpod_test.dart';

/// The variables `dartway test` sets so Serverpod can find the database it
/// created. `config/test.yaml` deliberately states `port: 0` — the port belongs
/// to a container Docker has not started yet — so **without these the suite has
/// no database to reach at all**, whatever is running locally.
const _required = [
  'SERVERPOD_DATABASE_HOST',
  'SERVERPOD_DATABASE_PORT',
  'SERVERPOD_DATABASE_NAME',
  'SERVERPOD_DATABASE_USER',
  'SERVERPOD_DATABASE_PASSWORD',
];

/// Call this as the first statement of an integration suite's `main`.
///
/// Throws before any test is registered when the database coordinates are
/// absent, so `dart test` reports a load failure carrying the reason instead of
/// a silent exit.
void requireTestDatabase() {
  final missing = _required
      .where((key) => (Platform.environment[key] ?? '').isEmpty)
      .toList();
  if (missing.isEmpty) return;

  throw StateError(
    'This suite needs a database, and none is configured.\n'
    '\n'
    'Run it with `dartway test` from the project root, not `dart test`: the '
    'command starts a Postgres container on a port Docker picks, applies the '
    'migrations and passes the coordinates through ${_required.join(', ')}. '
    '${missing.length == _required.length ? 'None of those are set' : '${missing.join(', ')} '
              '${missing.length == 1 ? 'is' : 'are'} not set'}.\n'
    '\n'
    'Re-run with DW_TEST_VERBOSE=1 to let the test server report its own '
    'startup, which it otherwise keeps to itself.',
  );
}

/// How much the test server is allowed to say.
///
/// `normal` keeps a passing run quiet, which is right nearly always. It is the
/// second move for the failures [requireTestDatabase] cannot see coming — the
/// coordinates are set but point at a database that is not ours, or the
/// password is wrong.
///
/// **What it was observed to do, rather than what it promises:** with
/// coordinates pointing at a closed port, the connection error reaches the
/// terminal either way; `verbose` adds the server's own frames beneath it.
/// The case it is really kept for — a reachable database that is the wrong one,
/// where the failure comes later, out of migrations — needs Docker to
/// reproduce and was not tried here.
TestServerOutputMode get testServerOutputMode =>
    (Platform.environment['DW_TEST_VERBOSE'] ?? '').isEmpty
    ? TestServerOutputMode.normal
    : TestServerOutputMode.verbose;
