// Runs a created project's `.github/workflows/ci.yml` on this machine, step by
// step, the way GitHub runs it — the `template` leg of `database.yml` (#495).
//
// The workflow file is the project's list of gates; the framework proves the
// skeleton by running that file rather than a copy that could drift from it.
// Reading it is `package:dartway_repo_tools/src/project_ci.dart`, which knows
// exactly the constructs the skeleton uses and refuses any other, so a gate
// added in a form this runner does not understand stops it instead of being
// skipped.
//
// What it does with the file:
// - `services:` start with `docker run`, each declared container port
//   published on a host port Docker picks, and are removed at the end;
// - `uses:` steps are skipped: checkout and the toolchain are already here;
// - `run:` steps run as `bash -e` in their `working-directory`, with the job's
//   and the step's `env:`, and `GITHUB_ENV` / `GITHUB_OUTPUT` honoured;
// - the event is a pull request whose base is the project's `HEAD`;
// - every step runs under its own guard, so one red gate does not hide the
//   next, and the exit code is non-zero when any step failed.
//
// Usage: dart run tool/run_project_ci.dart <project-dir>

import 'dart:async';
import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';

const _workflowPath = '.github/workflows/ci.yml';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/run_project_ci.dart <project-dir>');
    exit(64);
  }
  final project = Directory(args.single).absolute;
  final file = File('${project.path}/$_workflowPath');
  if (!file.existsSync()) {
    stderr.writeln('No $_workflowPath in ${project.path}');
    exit(1);
  }

  final ProjectCiWorkflow workflow;
  try {
    workflow = ProjectCiWorkflow.parse(file.readAsStringSync());
  } on ProjectCiRefusal catch (refusal) {
    _refuse(refusal);
  }

  final containers = <String>[];
  Future<void> removeContainers() async {
    for (final id in containers) {
      await Process.run('docker', ['rm', '--force', id]);
    }
    containers.clear();
  }

  final signals = [ProcessSignal.sigint, ProcessSignal.sigterm]
      .map(
        (signal) => signal.watch().listen((_) async {
          await removeContainers();
          exit(130);
        }),
      )
      .toList();

  final temp = Directory.systemTemp.createTempSync('dw_project_ci');
  final results = <(String, String, Duration)>[];
  try {
    final servicePorts = <String, Map<int, int>>{};
    for (final service in workflow.services.values) {
      final id = await _startService(service);
      containers.add(id);
      servicePorts[service.name] = {
        for (final port in service.ports) port: await _hostPort(id, port),
      };
      stdout.writeln(
        'service ${service.name}: ${service.image}, ports '
        '${servicePorts[service.name]}',
      );
    }

    final context = ProjectCiContext(
      baseSha: await _git(project, ['rev-parse', 'HEAD']),
      defaultBranch: await _git(project, ['rev-parse', '--abbrev-ref', 'HEAD']),
      servicePorts: servicePorts,
    );
    final githubEnv = <String, String>{};
    final outcomes = <String, String>{};
    var anyFailed = false;

    for (final (index, step) in workflow.steps.indexed) {
      final String outcome;
      final started = DateTime.now();
      if (!projectCiStepRuns(step, outcomes: outcomes, anyFailed: anyFailed)) {
        outcome = 'skipped';
        stdout.writeln('\n── ${step.label}: skipped');
      } else if (step.uses != null) {
        outcome = 'success';
        stdout.writeln('\n── ${step.label}: uses ${step.uses}, not run here');
      } else {
        stdout.writeln('\n── ${step.label}');
        outcome = await _runStep(
          step,
          index: index,
          project: project,
          temp: temp,
          workflow: workflow,
          context: context,
          githubEnv: githubEnv,
        );
      }
      if (step.id case final id?) outcomes[id] = outcome;
      if (outcome == 'failure') anyFailed = true;
      results.add((step.label, outcome, DateTime.now().difference(started)));
    }
  } on ProjectCiRefusal catch (refusal) {
    await removeContainers();
    _refuse(refusal);
  } finally {
    await removeContainers();
    temp.deleteSync(recursive: true);
    for (final subscription in signals) {
      unawaited(subscription.cancel());
    }
  }

  stdout.writeln('\n${workflow.jobId}:');
  for (final (label, outcome, took) in results) {
    final mark = switch (outcome) {
      'success' => '✓',
      'failure' => '✗',
      _ => '-',
    };
    stdout.writeln('  $mark $label ($outcome, ${took.inSeconds}s)');
  }
  final failed = results.where((result) => result.$2 == 'failure').length;
  if (failed > 0) {
    stderr.writeln('$failed step(s) failed');
    exit(1);
  }
  stdout.writeln('every step green');
}

Never _refuse(ProjectCiRefusal refusal) {
  stderr.writeln(
    'Refusing to run $_workflowPath: it uses what this runner does not '
    'understand, and running it anyway could skip a gate in silence. Teach '
    'tool/lib/src/project_ci.dart the construct, or keep the workflow to '
    'what it knows.',
  );
  for (final problem in refusal.problems) {
    stderr.writeln('  $problem');
  }
  exit(2);
}

Future<String> _runStep(
  ProjectCiStep step, {
  required int index,
  required Directory project,
  required Directory temp,
  required ProjectCiWorkflow workflow,
  required ProjectCiContext context,
  required Map<String, String> githubEnv,
}) async {
  final directory = Directory(
    step.workingDirectory == null
        ? project.path
        : '${project.path}/${step.workingDirectory}',
  );
  if (!directory.existsSync()) {
    stderr.writeln('No working directory ${directory.path}');
    return 'failure';
  }
  final script = File('${temp.path}/step_$index.sh')
    ..writeAsStringSync(context.resolve(step.run!));
  final envFile = File('${temp.path}/env_$index')..createSync();
  final outputFile = File('${temp.path}/output_$index')..createSync();

  // GitHub's order: the job's `env:`, then what earlier steps wrote to
  // GITHUB_ENV, then the step's own `env:`.
  final environment = {
    ...Platform.environment,
    for (final MapEntry(:key, :value) in workflow.env.entries)
      key: context.resolve(value),
    ...githubEnv,
    for (final MapEntry(:key, :value) in step.env.entries)
      key: context.resolve(value),
    'CI': 'true',
    'GITHUB_WORKSPACE': project.path,
    'GITHUB_ENV': envFile.path,
    'GITHUB_OUTPUT': outputFile.path,
  };
  final process = await Process.start(
    'bash',
    ['-e', script.path],
    workingDirectory: directory.path,
    environment: environment,
    includeParentEnvironment: false,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;

  githubEnv.addAll(parseGithubFile(envFile.readAsStringSync()));
  if (step.id case final id?) {
    context.outputs[id] = parseGithubFile(outputFile.readAsStringSync());
  }
  if (code != 0) stderr.writeln('${step.label}: exit code $code');
  return code == 0 ? 'success' : 'failure';
}

/// Starts [service] and waits for its health check, when it declares one.
Future<String> _startService(ProjectCiService service) async {
  final run = await Process.run('docker', [
    'run',
    '--detach',
    '--rm',
    for (final port in service.ports) ...['--publish', '$port'],
    for (final MapEntry(:key, :value) in service.env.entries) ...[
      '--env',
      '$key=$value',
    ],
    ...service.options,
    service.image,
  ]);
  if (run.exitCode != 0) {
    throw StateError('service ${service.name} did not start: ${run.stderr}');
  }
  final id = '${run.stdout}'.trim();

  final deadline = DateTime.now().add(const Duration(minutes: 3));
  while (true) {
    final inspect = await Process.run('docker', [
      'inspect',
      '--format',
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}',
      id,
    ]);
    final status = '${inspect.stdout}'.trim();
    if (status == 'healthy' || status == 'none') return id;
    if (status == 'unhealthy' || DateTime.now().isAfter(deadline)) {
      await Process.run('docker', ['rm', '--force', id]);
      throw StateError('service ${service.name} is $status');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

Future<int> _hostPort(String container, int port) async {
  final result = await Process.run('docker', ['port', container, '$port/tcp']);
  final line = '${result.stdout}'.split('\n').first.trim();
  final hostPort = int.tryParse(line.substring(line.lastIndexOf(':') + 1));
  if (result.exitCode != 0 || hostPort == null) {
    throw StateError('no host port for $container:$port: ${result.stderr}');
  }
  return hostPort;
}

Future<String> _git(Directory project, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: project.path);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} in ${project.path}: ${result.stderr}',
    );
  }
  return '${result.stdout}'.trim();
}
