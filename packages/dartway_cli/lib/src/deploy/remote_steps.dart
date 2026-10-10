import 'dart:math';

import 'package:path/path.dart' as p;

import 'disk_space.dart';
import 'output_mask.dart';
import 'secret_store.dart';
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

  /// No exit code, with a failed exit write or less than 1 GiB available.
  diskFull,

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

/// A remote result whose missing exit code was diagnosed on the server.
class DwRemoteStepResult extends DwSshResult {
  const DwRemoteStepResult({
    required this.state,
    required super.exitCode,
    required super.stdout,
    required super.stderr,
  });

  final DwRemoteStepState state;
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
  /// deployment stops on it instead of taking the exit code's word
  /// (`--retry-failed` is what runs it again).
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
  if [ "\$state" = vanished ]; then
    ${_diskFacts(r'$id')}
  fi
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
    final records = <String, DwRemoteStepRecord>{};
    for (final line in lines) {
      final words = line.split(' ');
      if (words.length < 2 ||
          ![
            'pending',
            'running',
            'vanished',
            'rejected',
            'exited',
          ].contains(words[1])) {
        continue;
      }
      records[words.first] = words[1] == 'vanished'
          ? DwRemoteStepRecord(_StoppedStep.parse(lines, words.first).state)
          : _record(words.skip(1).toList());
    }
    return records;
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
elif [ -f "$d/$id.pid" ] || [ -f "$d/$id.exit.tmp" ]; then state=vanished
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
rm -f "\$d/$id.exit" "\$d/$id.exit.tmp" "\$d/$id.rejected" "\$d/$id.pid" "\$d/$id.out" "\$d/$id.err"
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
  /// reads: `<nonce> exited <code>`, its stdout, `<nonce> stderr`, its stderr,
  /// then `<nonce> end <mask-code>`. A complete frame survives SSH disconnecting
  /// after it; its mask status, rather than SSH's exit code, judges the filter.
  String _waitScript(String id, String nonce) =>
      '''
d='$directory'
id='$id'
${dwSecretMaskFunction('${p.posix.dirname(directory)}/${DwSecretStore.fileName}')}
while :; do
  $_stateOf
  case "\$state" in
    running) sleep 0.2 ;;
    pending) echo "$nonce unstarted"; exit 0 ;;
    *) break ;;
  esac
done
if [ -f "\$d/$id.exit" ]; then
  dw_mask_code=0
  echo "$nonce exited \$(cat "\$d/$id.exit")"
  ${dwMaskOutputFile('"\$d/$id.out"')} || dw_mask_code=1
  echo
  echo "$nonce stderr"
  ${dwMaskOutputFile('"\$d/$id.err"')} || dw_mask_code=1
  echo
  echo "$nonce end \$dw_mask_code"
  exit "\$dw_mask_code"
else
  echo "$nonce vanished"
  ${_diskFacts(nonce)}
fi
''';

  String _diskFacts(String prefix) =>
      '''
$dwDiskSpaceFunction
$dwDockerRootScript
if [ -f "\$d/\$id.exit.tmp" ]; then echo "$prefix exit-tmp 1"
else echo "$prefix exit-tmp 0"; fi
for dw_path in "\$d" "\$dw_docker_root"; do
  printf '%s disk\\t' "$prefix"
  dw_disk_space "\$dw_path" || printf '%s\\tunavailable\\tunavailable\\n' "\$dw_path"
done
echo "$prefix end"
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
          if (!lines.contains('$nonce end')) return null;
          final stopped = _StoppedStep.parse(lines, nonce);
          if (stopped.paths.length != 2) return null;
          return DwRemoteStepResult(
            state: stopped.state,
            exitCode: 1,
            stdout: '',
            stderr: stopped.state == DwRemoteStepState.diskFull
                ? 'Step "$id" stopped on the server: the disk is full — '
                      '${stopped.shortPath}. Free space (old images, the build cache) '
                      'and run again with --resume.'
                : 'Step "$id" stopped on the server without an exit code — '
                      'the machine restarted, or something killed it.\n'
                      'Free space: ${stopped.spaceLine}.',
          );
        case 'exited':
          final rest = lines.sublist(index + 1).join('\n');
          final split = rest.indexOf('\n$nonce stderr\n');
          final endMarker = '\n$nonce end ';
          final end = rest.lastIndexOf(endMarker);
          if (split < 0 || end < split) return null;
          final maskCode = int.tryParse(
            rest.substring(end + endMarker.length).split('\n').first.trim(),
          );
          if (maskCode == null) return null;
          return DwSshResult(
            exitCode: maskCode == 0 ? int.tryParse(words.last) ?? 1 : maskCode,
            stdout: rest.substring(0, split),
            stderr:
                rest.substring(split + '\n$nonce stderr\n'.length, end) +
                (maskCode == 0 ? '' : answer.stderr),
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

class _StoppedStep {
  _StoppedStep(this.exitTmp, this.paths);

  final bool exitTmp;
  final List<(String, DwDiskSpace?)> paths;

  static _StoppedStep parse(List<String> lines, String prefix) =>
      _StoppedStep(lines.contains('$prefix exit-tmp 1'), [
        for (final line in lines)
          if (line.startsWith('$prefix disk\t'))
            (
              line.substring('$prefix disk\t'.length).split('\t').first,
              DwDiskSpace.parse(line.substring('$prefix disk\t'.length)),
            ),
      ]);

  DwDiskSpace? get shortSpace => paths
      .map((path) => path.$2)
      .whereType<DwDiskSpace>()
      .where((space) => space.freeBytes < 1024 * 1024 * 1024)
      .firstOrNull;

  DwRemoteStepState get state => exitTmp || shortSpace != null
      ? DwRemoteStepState.diskFull
      : DwRemoteStepState.vanished;

  String get shortPath => shortSpace?.description ?? _describe(paths.first);
  String get spaceLine => paths.map(_describe).join('; ');
  static String _describe((String, DwDiskSpace?) path) =>
      path.$2?.description ?? '${path.$1}: free space unavailable';
}
