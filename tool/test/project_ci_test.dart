import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Reading a project's CI workflow for `tool/run_project_ci.dart` (#495): the
/// skeleton's own file is read, and everything else is refused by name rather
/// than skipped.
void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (!Directory('${dir.path}/template').existsSync()) {
      final up = dir.parent;
      if (up.path == dir.path) throw StateError('not inside the monorepo');
      dir = up;
    }
    return dir;
  }();

  const guard = r"${{ !cancelled() && steps.deps.outcome == 'success' }}";

  String workflow({String job = '', String steps = ''}) =>
      '''
name: CI
on:
  pull_request:
jobs:
  ci:
    runs-on: ubuntu-latest
$job
    steps:
      - uses: actions/checkout@v4
      - name: pub get
        id: deps
        run: dart pub get
$steps
''';

  List<String> problems(String source) {
    try {
      ProjectCiWorkflow.parse(source);
    } on ProjectCiRefusal catch (refusal) {
      return refusal.problems;
    }
    fail('the workflow was accepted');
  }

  test('the skeleton\'s own workflow is one the runner can run', () {
    final source = File(
      '${repository.path}/template/.github/workflows/ci.yml',
    ).readAsStringSync();
    final parsed = ProjectCiWorkflow.parse(source);

    expect(parsed.jobId, 'ci');
    expect(parsed.services.keys, ['postgres']);
    expect(parsed.services['postgres']!.ports, [5432]);
    expect(
      parsed.steps.where((step) => step.afterStep == 'deps'),
      hasLength(9),
    );
  });

  test('every construct it does not know is refused, all of them at once', () {
    final found = problems(
      workflow(
        job: '    continue-on-error: true',
        steps: '''
      - name: deploy
        uses: some/deploy@v1
      - name: secret
        run: echo \${{ secrets.TOKEN }}
      - name: always
        if: \${{ always() }}
        run: dart test
      - name: tolerated
        continue-on-error: true
        run: dart analyze
''',
      ),
    );

    expect(found, [
      'job ci: unknown key "continue-on-error"',
      contains('uses some/deploy@v1'),
      contains('unknown expression `secrets.TOKEN`'),
      contains('if: \${{ always() }}'),
      'step "tolerated": unknown key "continue-on-error"',
    ]);
  });

  test('a second job, a fixed host port and an unclosed expression are '
      'refused', () {
    expect(
      problems('''
on: pull_request
jobs:
  one:
    steps: [{run: a}]
  two:
    steps: [{run: b}]
'''),
      ['expected exactly one job under jobs:'],
    );

    expect(
      problems(
        workflow(
          job: '''
    services:
      postgres:
        image: postgres:17-alpine
        ports: ['5432:5432']''',
          steps: r'''
      - run: echo ${{ github.sha''',
        ),
      ),
      [contains('port "5432:5432"'), contains('unclosed')],
    );
  });

  test('a guard or an output names only an earlier step', () {
    expect(
      problems(
        workflow(
          steps:
              '''
      - name: early
        if: ${guard.replaceAll('deps', 'later')}
        run: dart test
      - name: later
        id: later
        run: echo "v=1" >> "\$GITHUB_OUTPUT"
      - name: reads
        env:
          V: \${{ steps.nowhere.outputs.v }}
        run: echo "\$V"
''',
        ),
      ),
      [contains('names no earlier step "later"'), contains('names no earlier')],
    );
  });

  test('a guarded step runs once the step it names succeeded, even after '
      'another failed; an unguarded one only while nothing failed', () {
    final guarded = ProjectCiStep(label: 'gate', afterStep: 'deps');
    final unguarded = ProjectCiStep(label: 'setup');

    expect(
      projectCiStepRuns(
        guarded,
        outcomes: {'deps': 'success'},
        anyFailed: true,
      ),
      isTrue,
    );
    expect(
      projectCiStepRuns(
        guarded,
        outcomes: {'deps': 'failure'},
        anyFailed: true,
      ),
      isFalse,
    );
    expect(
      projectCiStepRuns(unguarded, outcomes: {}, anyFailed: true),
      isFalse,
    );
    expect(
      projectCiStepRuns(unguarded, outcomes: {}, anyFailed: false),
      isTrue,
    );
  });

  test('the known expressions resolve, and an output nobody wrote is '
      'refused', () {
    final context = ProjectCiContext(
      baseSha: 'abc123',
      defaultBranch: 'main',
      servicePorts: {
        'postgres': {5432: 49153},
      },
    )..outputs['fvm'] = {'version': '3.47.6'};

    expect(
      context.resolve(
        r"${{ github.event.pull_request.base.sha }} "
        r"${{ github.event.repository.default_branch }} "
        r"${{ job.services.postgres.ports['5432'] }} "
        r'${{ steps.fvm.outputs.version }}',
      ),
      'abc123 main 49153 3.47.6',
    );
    expect(
      () => context.resolve(r'${{ steps.fvm.outputs.channel }}'),
      throwsA(isA<ProjectCiRefusal>()),
    );
  });

  test('GITHUB_ENV and GITHUB_OUTPUT are read as KEY=VALUE, and the '
      'multi-line form is refused', () {
    expect(parseGithubFile('A=1\nB=x=y\n\n'), {'A': '1', 'B': 'x=y'});
    expect(
      () => parseGithubFile('A<<EOF\n1\nEOF\n'),
      throwsA(isA<ProjectCiRefusal>()),
    );
  });
}
