/// Reading a project's `.github/workflows/ci.yml` to run it outside GitHub
/// (`tool/run_project_ci.dart`, the `template` leg of `database.yml`).
///
/// The workflow file is the project's list of gates (#495), and the framework
/// proves the skeleton by running that file, not a copy of it. A copy would
/// drift; so would a runner that guessed. This one knows exactly the
/// constructs the skeleton's workflow uses and refuses everything else, all at
/// once and by name: an unknown expression, step key, action or `if:` is a gate
/// this runner would otherwise skip or misread in silence, and a gate skipped
/// in silence is green by construction.
library;

import 'package:yaml/yaml.dart';

/// A workflow this runner cannot run faithfully, with every reason found.
class ProjectCiRefusal implements Exception {
  ProjectCiRefusal(this.problems);

  final List<String> problems;

  @override
  String toString() => 'ProjectCiRefusal:\n  ${problems.join('\n  ')}';
}

/// A `services:` container: started on the machine, its ports published on
/// host ports Docker picks.
class ProjectCiService {
  ProjectCiService({
    required this.name,
    required this.image,
    required this.env,
    required this.options,
    required this.ports,
  });

  final String name;
  final String image;
  final Map<String, String> env;

  /// The `options:` string split on whitespace — passed to `docker run` as
  /// GitHub passes it to `docker create`.
  final List<String> options;

  /// Container ports only: a fixed host port is refused.
  final List<int> ports;
}

/// One step of the job.
class ProjectCiStep {
  ProjectCiStep({
    required this.label,
    this.id,
    this.uses,
    this.run,
    this.workingDirectory,
    this.env = const {},
    this.afterStep,
  });

  /// `name:`, or what the step uses, or the first line of what it runs.
  final String label;
  final String? id;

  /// An action this runner does not execute: checkout and the toolchain are
  /// already on the machine that runs the project.
  final String? uses;
  final String? run;
  final String? workingDirectory;
  final Map<String, String> env;

  /// The id in `!cancelled() && steps.<id>.outcome == 'success'`, the one
  /// guard a step may carry. Null: GitHub's default, the step runs only while
  /// no earlier step failed.
  final String? afterStep;
}

/// The single job of a project's CI workflow.
class ProjectCiWorkflow {
  ProjectCiWorkflow._({
    required this.jobId,
    required this.env,
    required this.services,
    required this.steps,
  });

  /// The actions a step may use. Anything else could be a gate, and this
  /// runner skips every `uses:` step.
  static const allowedActions = [
    'actions/checkout@',
    'subosito/flutter-action@',
  ];

  /// The one expression `runs-on:` may hold: the runner labels come from the
  /// `DW_CI_RUNS_ON` variable, `ubuntu-latest` without it. Where the steps run
  /// is GitHub's question; here they run on this machine, so it is accepted
  /// and ignored.
  static const runsOnExpression =
      r'''${{ fromJSON(vars.DW_CI_RUNS_ON || '"ubuntu-latest"') }}''';

  static const _topKeys = {'name', 'on', 'concurrency', 'permissions', 'jobs'};
  static const _jobKeys = {
    'name',
    'runs-on',
    'timeout-minutes',
    'services',
    'env',
    'steps',
  };
  static const _serviceKeys = {'image', 'env', 'options', 'ports'};
  static const _stepKeys = {
    'name',
    'id',
    'if',
    'run',
    'uses',
    'with',
    'working-directory',
    'env',
  };

  final String jobId;
  final Map<String, String> env;
  final Map<String, ProjectCiService> services;
  final List<ProjectCiStep> steps;

  /// Reads [source], or throws [ProjectCiRefusal] listing every construct
  /// this runner does not know.
  static ProjectCiWorkflow parse(String source) {
    final problems = <String>[];
    final Object? document;
    try {
      document = loadYaml(source);
    } on YamlException catch (error) {
      throw ProjectCiRefusal(['not valid YAML: ${error.message}']);
    }
    if (document is! YamlMap) {
      throw ProjectCiRefusal(['not a YAML mapping']);
    }
    _unknownKeys(document, _topKeys, 'the workflow', problems);

    final jobs = document['jobs'];
    if (jobs is! YamlMap || jobs.length != 1) {
      throw ProjectCiRefusal([
        ...problems,
        'expected exactly one job under jobs:',
      ]);
    }
    final jobId = '${jobs.keys.single}';
    final job = jobs.values.single;
    if (job is! YamlMap) {
      throw ProjectCiRefusal([...problems, 'job $jobId is not a mapping']);
    }
    _unknownKeys(job, _jobKeys, 'job $jobId', problems);
    final runsOn = job['runs-on'];
    if (runsOn is String &&
        runsOn.contains(r'${{') &&
        runsOn.trim() != runsOnExpression) {
      problems.add(
        'job $jobId: runs-on: $runsOn — the one expression known is '
        '`$runsOnExpression`',
      );
    }

    final services = <String, ProjectCiService>{};
    final rawServices = job['services'];
    if (rawServices != null && rawServices is! YamlMap) {
      problems.add('services: is not a mapping');
    } else if (rawServices is YamlMap) {
      for (final MapEntry(:key, :value) in rawServices.entries) {
        final service = _service('$key', value, problems);
        if (service != null) services[service.name] = service;
      }
    }

    final known = _Known(services: services);
    final env = _strings(job['env'], 'job env', problems);
    for (final MapEntry(:key, :value) in env.entries) {
      known.check(value, 'job env $key', problems);
    }

    final steps = <ProjectCiStep>[];
    final rawSteps = job['steps'];
    if (rawSteps is! YamlList || rawSteps.isEmpty) {
      problems.add('job $jobId has no steps');
    } else {
      for (final (index, raw) in rawSteps.indexed) {
        final step = _step(index + 1, raw, known, problems);
        if (step == null) continue;
        steps.add(step);
        if (step.id case final id?) known.stepIds.add(id);
      }
    }

    if (problems.isNotEmpty) throw ProjectCiRefusal(problems);
    return ProjectCiWorkflow._(
      jobId: jobId,
      env: env,
      services: services,
      steps: steps,
    );
  }

  static ProjectCiService? _service(
    String name,
    Object? raw,
    List<String> problems,
  ) {
    final where = 'service $name';
    if (raw is! YamlMap) {
      problems.add('$where is not a mapping');
      return null;
    }
    _unknownKeys(raw, _serviceKeys, where, problems);
    final image = raw['image'];
    if (image is! String || image.contains(r'${{')) {
      problems.add('$where: image: must be a plain string');
    }
    final rawOptions = raw['options'];
    var options = const <String>[];
    if (rawOptions is String &&
        !rawOptions.contains(RegExp(r'''['"]''')) &&
        !rawOptions.contains(r'${{')) {
      options = rawOptions.split(RegExp(r'\s+'));
      options.removeWhere((part) => part.isEmpty);
    } else if (rawOptions != null) {
      problems.add(
        '$where: options: must be a plain string with no quotes or '
        'expressions',
      );
    }
    final ports = <int>[];
    final rawPorts = raw['ports'];
    if (rawPorts is! YamlList) {
      problems.add('$where: ports: must be a list of container ports');
    } else {
      for (final port in rawPorts) {
        final number = int.tryParse('$port');
        if (number == null) {
          problems.add(
            '$where: port "$port" is not a bare container port — a fixed '
            'host port collides with whatever else runs on the machine',
          );
        } else {
          ports.add(number);
        }
      }
    }
    final env = _strings(raw['env'], '$where env', problems);
    for (final MapEntry(:key, :value) in env.entries) {
      if (value.contains(r'${{')) {
        problems.add('$where env $key: expressions are not supported here');
      }
    }
    return ProjectCiService(
      name: name,
      image: image is String ? image : '',
      env: env,
      options: options,
      ports: ports,
    );
  }

  static ProjectCiStep? _step(
    int number,
    Object? raw,
    _Known known,
    List<String> problems,
  ) {
    if (raw is! YamlMap) {
      problems.add('step $number is not a mapping');
      return null;
    }
    final name = raw['name'];
    final uses = raw['uses'];
    final run = raw['run'];
    final label = switch ((name, uses, run)) {
      (final String name, _, _) => name,
      (_, final String uses, _) => uses,
      (_, _, final String run) => run.split('\n').first,
      _ => 'step $number',
    };
    final where = 'step "$label"';
    _unknownKeys(raw, _stepKeys, where, problems);

    if ((uses == null) == (run == null)) {
      problems.add('$where: needs exactly one of run: and uses:');
    }
    if (uses != null &&
        (uses is! String ||
            !allowedActions.any((prefix) => uses.startsWith(prefix)))) {
      problems.add(
        '$where: uses $uses — only ${allowedActions.join('*, ')}* are known; '
        'any other action could be a gate this runner would skip',
      );
    }
    if (run != null && run is! String) {
      problems.add('$where: run: is not a string');
    }
    if (run is String) known.check(run, '$where run', problems);
    if (uses == null && raw['with'] != null) {
      problems.add('$where: with: belongs to a uses: step');
    }
    final withValues = _strings(raw['with'], '$where with', problems);
    for (final MapEntry(:key, :value) in withValues.entries) {
      known.check(value, '$where with $key', problems);
    }

    final id = raw['id'];
    if (id != null && (id is! String || !_identifier.hasMatch(id))) {
      problems.add('$where: id "$id" is not an identifier');
    }

    final workingDirectory = raw['working-directory'];
    if (workingDirectory != null &&
        (workingDirectory is! String ||
            workingDirectory.contains(r'${{') ||
            workingDirectory.startsWith('/') ||
            workingDirectory.split('/').contains('..'))) {
      problems.add(
        '$where: working-directory must be a plain path inside the project',
      );
    }

    final env = _strings(raw['env'], '$where env', problems);
    for (final MapEntry(:key, :value) in env.entries) {
      known.check(value, '$where env $key', problems);
    }

    String? afterStep;
    final guard = raw['if'];
    if (guard != null) {
      final match = guard is String
          ? _guard.firstMatch(_unwrap(guard).trim())
          : null;
      if (match == null) {
        problems.add(
          "$where: if: $guard — the one guard known is "
          "`\${{ !cancelled() && steps.<id>.outcome == 'success' }}`",
        );
      } else {
        afterStep = match.group(1);
        if (!known.stepIds.contains(afterStep)) {
          problems.add('$where: if: names no earlier step "$afterStep"');
        }
      }
    }

    return ProjectCiStep(
      label: label,
      id: id is String ? id : null,
      uses: uses is String ? uses : null,
      run: run is String ? run : null,
      workingDirectory: workingDirectory is String ? workingDirectory : null,
      env: env,
      afterStep: afterStep,
    );
  }

  static void _unknownKeys(
    YamlMap map,
    Set<String> allowed,
    String where,
    List<String> problems,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains('$key')) {
        problems.add('$where: unknown key "$key"');
      }
    }
  }

  static Map<String, String> _strings(
    Object? raw,
    String where,
    List<String> problems,
  ) {
    if (raw == null) return const {};
    if (raw is! YamlMap) {
      problems.add('$where: not a mapping');
      return const {};
    }
    final result = <String, String>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (value is YamlMap || value is YamlList || value == null) {
        problems.add('$where $key: not a scalar');
      } else {
        result['$key'] = '$value';
      }
    }
    return result;
  }
}

/// Whether [step] runs, as GitHub decides it: under the guard, once the step
/// it names succeeded (a run is never cancelled here); without one, only
/// while no earlier step failed.
bool projectCiStepRuns(
  ProjectCiStep step, {
  required Map<String, String> outcomes,
  required bool anyFailed,
}) => switch (step.afterStep) {
  null => !anyFailed,
  final id => outcomes[id] == 'success',
};

/// The values the known expressions resolve to, for one run.
class ProjectCiContext {
  ProjectCiContext({
    required this.baseSha,
    required this.defaultBranch,
    required this.servicePorts,
  });

  /// `github.event.pull_request.base.sha`.
  final String baseSha;

  /// `github.event.repository.default_branch`.
  final String defaultBranch;

  /// Service name → container port → host port.
  final Map<String, Map<int, int>> servicePorts;

  /// Step id → output name → value, from each step's `GITHUB_OUTPUT`.
  final outputs = <String, Map<String, String>>{};

  /// [text] with every `${{ }}` replaced. Throws [ProjectCiRefusal] on
  /// anything [ProjectCiWorkflow.parse] would not have let through, or on an
  /// output no step wrote.
  String resolve(String text) {
    final problems = <String>[];
    final resolved = text.replaceAllMapped(_expression, (match) {
      final expression = match.group(1)!.trim();
      final value = _value(expression);
      if (value == null) problems.add('cannot resolve `$expression`');
      return value ?? '';
    });
    if (problems.isNotEmpty) throw ProjectCiRefusal(problems);
    return resolved;
  }

  String? _value(String expression) {
    if (expression == 'github.event.pull_request.base.sha') return baseSha;
    if (expression == 'github.event.repository.default_branch') {
      return defaultBranch;
    }
    if (_servicePort.firstMatch(expression) case final match?) {
      return servicePorts[match.group(1)]?[int.parse(match.group(2)!)]
          ?.toString();
    }
    if (_stepOutput.firstMatch(expression) case final match?) {
      return outputs[match.group(1)]?[match.group(2)];
    }
    return null;
  }
}

/// `KEY=VALUE` lines as a step writes them to `GITHUB_ENV` or
/// `GITHUB_OUTPUT`. The multi-line `KEY<<DELIMITER` form is refused: nothing
/// in the skeleton writes it, and reading it wrong would hand the next gate a
/// wrong value without a word.
Map<String, String> parseGithubFile(String contents) {
  final result = <String, String>{};
  for (final line in contents.split('\n')) {
    if (line.trim().isEmpty) continue;
    final equals = line.indexOf('=');
    final heredoc = line.indexOf('<<');
    if (equals <= 0 || (heredoc >= 0 && heredoc < equals)) {
      throw ProjectCiRefusal(['cannot read "$line": only KEY=VALUE is known']);
    }
    result[line.substring(0, equals)] = line.substring(equals + 1);
  }
  return result;
}

final _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$');
final _expression = RegExp(r'\$\{\{(.*?)\}\}', dotAll: true);
final _servicePort = RegExp(
  r"^job\.services\.([A-Za-z_][A-Za-z0-9_-]*)\.ports\['(\d+)'\]$",
);
final _stepOutput = RegExp(
  r'^steps\.([A-Za-z_][A-Za-z0-9_-]*)\.outputs\.([A-Za-z_][A-Za-z0-9_-]*)$',
);
final _guard = RegExp(
  r"^!cancelled\(\) && steps\.([A-Za-z_][A-Za-z0-9_-]*)\.outcome == 'success'$",
);

String _unwrap(String guard) {
  final trimmed = guard.trim();
  return trimmed.startsWith(r'${{') && trimmed.endsWith('}}')
      ? trimmed.substring(3, trimmed.length - 2)
      : trimmed;
}

/// What an expression may name while the workflow is read: the two event
/// fields, a declared service's declared port, an earlier step's output.
class _Known {
  _Known({required this.services});

  final Map<String, ProjectCiService> services;
  final stepIds = <String>{};

  void check(String text, String where, List<String> problems) {
    final unclosed = text.replaceAll(_expression, '');
    if (unclosed.contains(r'${{')) {
      problems.add('$where: an unclosed `\${{`');
    }
    for (final match in _expression.allMatches(text)) {
      final expression = match.group(1)!.trim();
      if (expression == 'github.event.pull_request.base.sha' ||
          expression == 'github.event.repository.default_branch') {
        continue;
      }
      if (_servicePort.firstMatch(expression) case final port?) {
        final service = services[port.group(1)];
        if (service == null ||
            !service.ports.contains(int.parse(port.group(2)!))) {
          problems.add('$where: `$expression` names no declared service port');
        }
        continue;
      }
      if (_stepOutput.firstMatch(expression) case final output?) {
        if (!stepIds.contains(output.group(1))) {
          problems.add('$where: `$expression` names no earlier step');
        }
        continue;
      }
      problems.add('$where: unknown expression `$expression`');
    }
  }
}
