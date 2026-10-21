import 'compose_files.dart';
import 'deploy_target.dart';
import 'output_mask.dart';
import 'renderer.dart';
import 'secret_store.dart';
import 'ssh_runner.dart';
import 'stack.dart';

/// One call's latency over the window, as the proxy saw it.
class DwCallLatency {
  const DwCallLatency({
    required this.call,
    required this.count,
    required this.p50,
    required this.p95,
    required this.max,
    required this.serverErrors,
  });

  /// The wire name.
  final String call;
  final int count;

  /// Seconds, nearest rank: the time at least this share of the calls took
  /// no longer than.
  final double p50;
  final double p95;
  final double max;

  /// Answers of 500 and above.
  final int serverErrors;
}

/// One statement shape of `pg_stat_statements`.
class DwStatementCost {
  const DwStatementCost({
    required this.calls,
    required this.totalMs,
    required this.meanMs,
    required this.rows,
    required this.query,
  });

  final int calls;
  final double totalMs;
  final double meanMs;
  final int rows;

  /// Normalised by Postgres — literals are `$1`, `$2` — and folded to one
  /// line.
  final String query;
}

/// What `dartway deploy stats` read on a server.
class DwDeployStatsReport {
  const DwDeployStatsReport({
    required this.calls,
    this.statements,
    this.statementsSince,
    this.statementsProblem,
    this.slowStatements,
  });

  /// Slowest p95 first.
  final List<DwCallLatency> calls;

  /// Most total time first; null when the database is not the bundled one,
  /// or the extension could not be read ([statementsProblem]).
  final List<DwStatementCost>? statements;

  /// When `pg_stat_statements` started counting: its counters are totals
  /// since then, not over the window.
  final String? statementsSince;
  final String? statementsProblem;

  /// Statements logged over `slow_query_ms` in the window.
  final int? slowStatements;
}

/// Reads the latency of a deployed environment, and changes nothing there:
/// p50/p95 per call over the last hours from the proxy's log, the
/// statements that cost the database most from `pg_stat_statements`, and
/// how many statements the slow-query log caught.
///
/// The proxy's log, not the server's: it is the one that holds every call
/// for as long as the proxy container lives, while a server container is
/// replaced by every deploy and its log with it. The percentiles are
/// computed on the server — sorted, then counted — so what crosses the
/// connection is one line per call name, not one per request.
class DwDeployStats {
  DwDeployStats({
    required DwSshRunner ssh,
    required this.stack,
    String? appDir,
  }) : appDir = appDir ?? stack.target.appDir,
       ssh = DwMaskedSshRunner(
        ssh,
        deployUser: stack.target.deployUser,
        storeFile: '${stack.target.runtimeConfigDir}/${DwSecretStore.fileName}',
      );

  final DwSshRunner ssh;
  final DwStack stack;

  /// The checkout, where Compose finds the stack.
  final String appDir;

  DwDeployTarget get _target => stack.target;

  static const String _callsMarker = '--dw-stats-calls--';
  static const String _slowMarker = '--dw-stats-slow--';
  static const String _statementsMarker = '--dw-stats-statements--';

  /// Turns the proxy's JSON lines on stdin into `call<TAB>seconds<TAB>status`
  /// lines: calls only — an empty `call` is anything else — and nothing
  /// that is not one of the rendered format's lines.
  static const String extractScript = r'''awk '
/^\{"time"/ {
  if (!match($0, /"call":"[^"]*"/)) next
  call = substr($0, RSTART + 8, RLENGTH - 9)
  if (call == "") next
  if (!match($0, /"request_time":[0-9.]+/)) next
  seconds = substr($0, RSTART + 15, RLENGTH - 15)
  status = 0
  if (match($0, /"status":[0-9]+/)) status = substr($0, RSTART + 9, RLENGTH - 9)
  printf "%s\t%s\t%s\n", call, seconds, status
}' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2n''';

  /// Reads what [extractScript] sorted and prints, per call,
  /// `call<TAB>count<TAB>p50<TAB>p95<TAB>max<TAB>5xx`. Nearest rank: the
  /// p-th percentile of n sorted times is the ⌈n·p/100⌉-th.
  static const String percentileScript = r'''awk -F '\t' '
function flush() {
  if (n == 0) return
  printf "%s\t%d\t%s\t%s\t%s\t%d\n", name, n, v[int((n * 50 + 99) / 100)], v[int((n * 95 + 99) / 100)], v[n], errors
}
$1 != name { flush(); name = $1; n = 0; errors = 0 }
{ v[++n] = $2; if ($3 + 0 >= 500) errors++ }
END { flush() }' ''';

  /// The script the server runs, as the deploy user, in the checkout.
  String script({required int hours, required int top}) {
    final since = '${hours}h';
    final bundled = _target.database == DwDatabaseMode.bundled;
    final name = stack.databaseName;
    final database = bundled
        ? '''
echo '$_slowMarker'
${DwComposeFiles.invoke} logs --no-color --no-log-prefix --since $since ${DwStack.postgresService} 2>&1 | grep -c ' duration: ' || true
echo '$_statementsMarker'
${DwComposeFiles.invoke} exec -T ${DwStack.postgresService} psql -X -q -A -t -F "\$(printf '\\t')" -v ON_ERROR_STOP=1 -U '$name' -d '$name' 2>&1 <<'DW_SQL' || true
SELECT 'since', stats_reset FROM pg_stat_statements_info;
SELECT calls, round(total_exec_time::numeric, 1), round(mean_exec_time::numeric, 1), rows,
  left(regexp_replace(query, '\\s+', ' ', 'g'), 200)
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY total_exec_time DESC
LIMIT $top;
DW_SQL
'''
        : '';
    return '''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
echo '$_callsMarker'
${DwComposeFiles.invoke} logs --no-color --no-log-prefix --since $since ${DwStack.nginxService} 2>/dev/null | $extractScript | $percentileScript
$database''';
  }

  Future<DwDeployStatsReport> read({int hours = 24, int top = 10}) async {
    final result = await ssh.runAs(
      _target.deployUser,
      script(hours: hours, top: top),
    );
    if (!result.ok) {
      throw StateError(
        'Cannot read the stats on the server: ${result.firstLine}',
      );
    }
    return parse(result.stdout);
  }

  /// [stdout] of [script], read.
  static DwDeployStatsReport parse(String stdout) {
    final sections = <String, List<String>>{};
    List<String>? current;
    for (final line in stdout.split('\n')) {
      if (line == _callsMarker ||
          line == _slowMarker ||
          line == _statementsMarker) {
        current = sections[line] = [];
      } else if (line.trim().isNotEmpty) {
        current?.add(line);
      }
    }
    final calls = [
      for (final line in sections[_callsMarker] ?? const <String>[])
        if (line.split('\t') case [
          final call,
          final count,
          final p50,
          final p95,
          final max,
          final errors,
        ])
          DwCallLatency(
            call: call,
            count: int.parse(count),
            p50: double.parse(p50),
            p95: double.parse(p95),
            max: double.parse(max),
            serverErrors: int.parse(errors),
          ),
    ]..sort((a, b) => b.p95.compareTo(a.p95));
    final slow = sections[_slowMarker]?.firstOrNull;
    final statementLines = sections[_statementsMarker];
    String? since;
    String? problem;
    List<DwStatementCost>? statements;
    if (statementLines != null) {
      final read = <DwStatementCost>[];
      for (final line in statementLines) {
        final fields = line.split('\t');
        if (fields.length == 2 && fields.first == 'since') {
          since = fields.last;
          continue;
        }
        final row = fields.length < 5
            ? null
            : (
                int.tryParse(fields[0]),
                double.tryParse(fields[1]),
                double.tryParse(fields[2]),
                int.tryParse(fields[3]),
              );
        if (row case (final calls?, final total?, final mean?, final rows?)) {
          read.add(
            DwStatementCost(
              calls: calls,
              totalMs: total,
              meanMs: mean,
              rows: rows,
              query: fields.sublist(4).join(' '),
            ),
          );
        } else {
          // psql names where it read the statement it refuses.
          problem ??= line.replaceFirst(RegExp(r'^psql:\S* '), '').trim();
        }
      }
      if (problem == null && since == null) {
        problem = 'the database did not answer';
      }
      if (problem == null) statements = read;
    }
    return DwDeployStatsReport(
      calls: calls,
      statements: statements,
      statementsSince: since,
      statementsProblem: problem,
      slowStatements: slow == null ? null : int.tryParse(slow.trim()),
    );
  }

  /// [report] for a person, in the words of where each number comes from.
  String format(DwDeployStatsReport report, {required int hours}) {
    final out = StringBuffer()
      ..writeln(
        'Calls through the proxy, last $hours h [${_target.environment}] — '
        "nginx's log, ${DwStackRenderer.accessLogFormat} format",
      );
    if (report.calls.isEmpty) {
      out.writeln(
        '  none logged. The proxy logs calls in this format since the first '
        'deploy by a CLI that renders it, and keeps its log until the proxy '
        'container is recreated.',
      );
    } else {
      final width = report.calls
          .map((row) => row.call.length)
          .fold(4, (a, b) => a > b ? a : b);
      String ms(double seconds) => (seconds * 1000).round().toString();
      out.writeln(
        '  ${'call'.padRight(width)}  ${'calls'.padLeft(7)}  '
        '${'p50 ms'.padLeft(7)}  ${'p95 ms'.padLeft(7)}  '
        '${'max ms'.padLeft(7)}  ${'5xx'.padLeft(5)}',
      );
      for (final row in report.calls) {
        out.writeln(
          '  ${row.call.padRight(width)}  ${'${row.count}'.padLeft(7)}  '
          '${ms(row.p50).padLeft(7)}  ${ms(row.p95).padLeft(7)}  '
          '${ms(row.max).padLeft(7)}  ${'${row.serverErrors}'.padLeft(5)}',
        );
      }
    }
    out.writeln();
    if (_target.database == DwDatabaseMode.external) {
      out.writeln(
        'Statements: the database is external — its provider shows them '
        '(pg_stat_statements, the slow-query log).',
      );
      return out.toString();
    }
    out.writeln(
      'Statements by total time — pg_stat_statements'
      '${report.statementsSince == null ? '' : ', counted since ${report.statementsSince}'}',
    );
    switch (report.statements) {
      case null:
        out.writeln(
          '  not readable: ${report.statementsProblem}. The extension is '
          'created by "dartway deploy run"; a database deployed before it '
          'has it from the next deploy.',
        );
      case []:
        out.writeln('  none counted yet.');
      case final statements:
        out.writeln(
          '  ${'total ms'.padLeft(10)}  ${'calls'.padLeft(8)}  '
          '${'mean ms'.padLeft(8)}  ${'rows'.padLeft(8)}  query',
        );
        for (final row in statements) {
          out.writeln(
            '  ${row.totalMs.toStringAsFixed(1).padLeft(10)}  '
            '${'${row.calls}'.padLeft(8)}  '
            '${row.meanMs.toStringAsFixed(1).padLeft(8)}  '
            '${'${row.rows}'.padLeft(8)}  ${row.query}',
          );
        }
    }
    if (report.slowStatements case final count?) {
      out
        ..writeln()
        ..writeln(
          'Statements over ${_target.slowQueryMs} ms, last $hours h: $count '
          '— the database log; read them with: docker compose logs '
          '${DwStack.postgresService} | grep "duration:"',
        );
    }
    return out.toString();
  }
}
