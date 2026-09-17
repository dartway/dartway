import 'dart:math';

import 'ssh_runner.dart';

/// What the server knows about one step of the last deployment.
enum DwRemoteStepState {
  /// Never started in the run the server remembers.
  pending,

  /// Its process is alive and has not written an exit code.
  running,

  /// Its process is gone without an exit code: the machine restarted, or
  /// something killed it.
  vanished,

  /// It ran to its end; the code is in [DwRemoteStepRecord.exitCode].
  exited,

  /// It exited 0 and the deployment judged that its work was not done.
  rejected,
}

/// A step as the server remembers it.
class DwRemoteStepRecord {
  const DwRemoteStepRecord(this.state, [this.exitCode]);

  final DwRemoteStepState state;
  final int? exitCode;

  bool get succeeded => state == DwRemoteStepState.exited && exitCode == 0;

  @override
  String toString() => switch (state) {
    DwRemoteStepState.exited => 'exited $exitCode',
    _ => state.name,
  };
}

/// Refused to start a deployment while another one is still running a step on
/// the same server.
class DwDeployBusy implements Exception {
  const DwDeployBusy(this.stepId);

  final String stepId;

  @override
  String toString() =>
      'A deployment is still running step "$stepId" on the server. Wait for '
      'it, or pick it up with --resume.';
}

/// Runs deployment steps on the server detached from the connection that
/// started them, and keeps what they did in a directory there.
///
/// A step's script is written to [directory] and started in its own session,
/// with no terminal and every stream redirected to a file, so neither a
/// dropped connection nor the death of the machine that invoked the deploy —
/// a container of the very stack being replaced — stops it. The call that
/// starts a step also waits for it, which keeps a routine deploy at one
/// connection per step; when that connection breaks, fresh ones wait for the
/// same step until [contactTolerance] runs out.
///
/// Files per step `<id>`: `.sh` the script, `.pid` its process, `.out` and
/// `.err` its streams, `.exit` its code (written last, atomically), `.rejected`
/// when the deployment refused an exit 0. `plan` lists the step ids of the
/// run in order.
class DwRemoteSteps {
  DwRemoteSteps({
    required this.ssh,
    required this.deployUser,
    required this.directory,
    this.pollInterval = const Duration(seconds: 5),
    this.contactTolerance = const Duration(minutes: 15),
    this.onNotice,
  });

  final DwSshRunner ssh;
  final String deployUser;
  final String directory;

  /// The pause between attempts to reach the server again.
  final Duration pollInterval;

  /// How long the server may stay out of reach while a step runs before the
  /// deployment gives up waiting — the step itself keeps running.
  final Duration contactTolerance;

  /// Told what the server said about a previous deployment, in words.
  final void Function(String notice)? onNotice;

  List<String>? _freshPlan;

  /// Makes the next [run] start a new deployment of [stepIds]: the record of
  /// the previous one is replaced — unless one of its steps is still running,
  /// which makes that [run] throw [DwDeployBusy].
  ///
  /// Nothing goes over the network here; the check and the reset travel with
  /// the first step.
  void beginFresh(List<String> stepIds) => _freshPlan = List.of(stepIds);

  /// Starts step [id] with [script] and waits for its end.
  Future<DwSshResult> run(String id, String script) async {
    final plan = _freshPlan;
    _freshPlan = null;
    final nonce = _nonce();
    final started = await ssh.runAsWithInput(
      deployUser,
      _startScript(id, nonce, plan),
      script,
    );
    return _settle(id, nonce, started);
  }

  /// Waits for step [id], started by an earlier invocation, and answers what
  /// it did — without running it again.
  Future<DwSshResult> collect(String id) async {
    final nonce = _nonce();
    return _settle(
      id,
      nonce,
      await ssh.runAs(deployUser, _waitScript(id, nonce)),
    );
  }

  /// Records that step [id] exited 0 without doing its work, so a resumed
  /// deployment runs it again instead of taking the exit code's word.
  Future<DwSshResult> reject(String id) =>
      ssh.runAs(deployUser, ": > '$directory/$id.rejected'");

  /// What the server remembers of the last deployment, step by step, or null
  /// when it remembers none.
  Future<Map<String, DwRemoteStepRecord>?> read() async {
    final result = await ssh.runAs(deployUser, '''
d='$directory'
[ -f "\$d/plan" ] || { echo none; exit 0; }
while read -r id; do
  [ -n "\$id" ] || continue
  $_stateOf
  echo "\$id \$state"
done <"\$d/plan"
''');
    if (!result.ok) {
      throw StateError(
        'Cannot read the deployment record on the server: '
        '${result.firstLine}',
      );
    }
    final lines = result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.first == 'none') return null;
    return {
      for (final line in lines)
        line.split(' ').first: _record(line.split(' ').skip(1).toList()),
    };
  }

  static DwRemoteStepRecord _record(List<String> words) =>
      switch (words.first) {
        'running' => const DwRemoteStepRecord(DwRemoteStepState.running),
        'vanished' => const DwRemoteStepRecord(DwRemoteStepState.vanished),
        'rejected' => const DwRemoteStepRecord(DwRemoteStepState.rejected),
        'exited' => DwRemoteStepRecord(
          DwRemoteStepState.exited,
          int.tryParse(words.last) ?? 1,
        ),
        _ => const DwRemoteStepRecord(DwRemoteStepState.pending),
      };

  /// Sets `state` for `$id` in `$d`, in the words [read] parses.
  static const String _stateOf = r'''
if [ -f "$d/$id.rejected" ]; then state=rejected
elif [ -f "$d/$id.exit" ]; then state="exited $(cat "$d/$id.exit")"
elif [ -f "$d/$id.pid" ] && kill -0 "$(cat "$d/$id.pid")" 2>/dev/null; then state=running
elif [ -f "$d/$id.pid" ]; then state=vanished
else state=pending
fi''';

  String _startScript(String id, String nonce, List<String>? plan) {
    final fresh = plan == null
        ? ''
        : '''
if [ -f "\$d/plan" ]; then
  while read -r id; do
    [ -n "\$id" ] || continue
    $_stateOf
    case "\$state" in
      running) echo "$nonce busy \$id"; exit 0 ;;
      "exited 0") done_any=1 ;;
      pending) [ -z "\$done_any" ] || echo "$nonce previous \$id pending"; break ;;
      *) echo "$nonce previous \$id \$state"; break ;;
    esac
  done <"\$d/plan"
fi
rm -rf "\$d"
mkdir -p "\$d"
printf '%s\\n' ${plan.map((step) => "'$step'").join(' ')} >"\$d/plan"
''';
    return '''
set -e
umask 077
d='$directory'
$fresh
mkdir -p "\$d"
rm -f "\$d/$id.exit" "\$d/$id.rejected" "\$d/$id.pid" "\$d/$id.out" "\$d/$id.err"
cat >"\$d/$id.sh"
cat >"\$d/$id.run" <<'DW_RUN'
trap '' HUP
echo \$\$ >"\$1/\$2.pid.tmp" && mv "\$1/\$2.pid.tmp" "\$1/\$2.pid"
code=0
sh "\$1/\$2.sh" >"\$1/\$2.out" 2>"\$1/\$2.err" </dev/null || code=\$?
echo "\$code" >"\$1/\$2.exit.tmp" && mv "\$1/\$2.exit.tmp" "\$1/\$2.exit"
DW_RUN
if command -v setsid >/dev/null 2>&1; then
  setsid sh "\$d/$id.run" "\$d" '$id' </dev/null >/dev/null 2>&1 &
else
  nohup sh "\$d/$id.run" "\$d" '$id' </dev/null >/dev/null 2>&1 &
fi
tries=0
while [ ! -f "\$d/$id.pid" ] && [ ! -f "\$d/$id.exit" ] && [ \$tries -lt 100 ]; do
  sleep 0.1; tries=\$((tries + 1))
done
${_waitScript(id, nonce)}''';
  }

  /// Waits for `<id>.exit` and prints the step's end in a frame [_settle]
  /// reads: `<nonce> exited <code>`, its stdout, `<nonce> stderr`, its stderr.
  String _waitScript(String id, String nonce) =>
      '''
d='$directory'
id='$id'
while :; do
  $_stateOf
  case "\$state" in
    running) sleep 0.2 ;;
    pending) echo "$nonce unstarted"; exit 0 ;;
    *) break ;;
  esac
done
if [ -f "\$d/$id.exit" ]; then
  echo "$nonce exited \$(cat "\$d/$id.exit")"
  cat "\$d/$id.out" 2>/dev/null || true
  echo
  echo "$nonce stderr"
  cat "\$d/$id.err" 2>/dev/null || true
  echo
  echo "$nonce end"
else
  echo "$nonce vanished"
fi
''';

  Future<DwSshResult> _settle(
    String id,
    String nonce,
    DwSshResult answer,
  ) async {
    var current = answer;
    Stopwatch? outOfReach;
    while (true) {
      final ended = _read(id, nonce, current, started: answer);
      if (ended != null) return ended;
      outOfReach ??= Stopwatch()..start();
      if (outOfReach.elapsed >= contactTolerance) {
        return DwSshResult(
          exitCode: 255,
          stdout: '',
          stderr:
              'Lost contact with the server while step "$id" was running '
              '(${current.firstLine}). The step keeps running there; pick it '
              'up with: dartway deploy run --resume',
        );
      }
      await Future<void>.delayed(pollInterval);
      current = await ssh.runAs(deployUser, _waitScript(id, nonce));
    }
  }

  /// The step's result from one answer of the server, or null when the answer
  /// carries none — the connection broke before the step ended.
  DwSshResult? _read(
    String id,
    String nonce,
    DwSshResult answer, {
    required DwSshResult started,
  }) {
    final lines = answer.stdout.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final words = lines[index].trim().split(' ');
      if (words.first != nonce || words.length < 2) continue;
      switch (words[1]) {
        case 'busy':
          throw DwDeployBusy(words.length > 2 ? words[2] : id);
        case 'previous':
          final state = words.skip(3).join(' ');
          onNotice?.call(
            state == 'pending'
                ? 'The previous deployment stopped before step "${words[2]}". '
                      'Starting a new one.'
                : 'The previous deployment did not finish: step "${words[2]}" '
                      '$state. Starting a new one.',
          );
        case 'unstarted':
          return started.ok
              ? DwSshResult(
                  exitCode: 1,
                  stdout: started.stdout,
                  stderr:
                      'Step "$id" did not start on the server.\n${started.stderr}',
                )
              : started;
        case 'vanished':
          return DwSshResult(
            exitCode: 1,
            stdout: '',
            stderr:
                'Step "$id" stopped on the server without an exit code — '
                'the machine restarted, or something killed it.',
          );
        case 'exited':
          final rest = lines.sublist(index + 1).join('\n');
          final split = rest.indexOf('\n$nonce stderr\n');
          final end = rest.lastIndexOf('\n$nonce end');
          if (split < 0 || end < split) return null;
          return DwSshResult(
            exitCode: int.tryParse(words.last) ?? 1,
            stdout: rest.substring(0, split),
            stderr: rest.substring(split + '\n$nonce stderr\n'.length, end),
          );
      }
    }
    return null;
  }

  static String _nonce() {
    final random = Random.secure();
    return '--dw-step-${List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join()}--';
  }
}
