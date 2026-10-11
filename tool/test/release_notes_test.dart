import 'dart:io';

import 'package:test/test.dart';

void main() {
  final script = File('release_notes.dart').absolute.path;

  test('release notes group issue-prefixed conventional titles and retain '
      'breaking markers and body references', () async {
    final repository = await Directory.systemTemp.createTemp('release_notes_');
    addTearDown(() => repository.delete(recursive: true));

    Future<String> git(List<String> arguments) async {
      final result = await Process.run('git', [
        '-c',
        'user.name=Release notes test',
        '-c',
        'user.email=release-notes@example.com',
        ...arguments,
      ], workingDirectory: repository.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return result.stdout.toString().trim();
    }

    await git(['init']);
    await git(['commit', '--allow-empty', '-m', 'chore: base']);
    final base = await git(['rev-parse', 'HEAD']);
    for (final subject in [
      '#536 fix(migrations): warn about ahead migrations on apply (#544)',
      '#408 feat(server)!: seeds as startup steps (#408)',
      'docs(toolkit): expand schemas for #520',
      'Upgrade Flutter pin',
    ]) {
      await git(['commit', '--allow-empty', '-m', subject]);
    }
    await git(['switch', '-c', 'side']);
    await git(['commit', '--allow-empty', '-m', 'feat: side change']);
    await git(['switch', '-c', 'main-line', 'HEAD~1']);
    await git(['commit', '--allow-empty', '-m', 'feat: main change']);
    await git(['merge', '--no-ff', 'side', '-m', 'chore: merge side branch']);

    final result = await Process.run(Platform.resolvedExecutable, [
      script,
      base,
      'HEAD',
    ], workingDirectory: repository.path);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final notes = result.stdout.toString();
    expect(
      notes,
      contains(
        '## Breaking\n\nRead these before upgrading — each one changes '
        'something an application already depends on.\n\n'
        '- **server** — seeds as startup steps (#408)\n\n',
      ),
    );
    expect(
      notes,
      contains(
        '## Fixed\n\n- **migrations** — warn about ahead migrations '
        'on apply (#544)\n\n',
      ),
    );
    expect(
      notes,
      contains(
        '## Documentation\n\n- **toolkit** — expand schemas for #520\n\n',
      ),
    );
    expect(notes, contains('## Other\n\n- Upgrade Flutter pin\n\n'));
    expect(notes, isNot(contains('#536 fix')));
    expect(notes, isNot(contains('#408 feat')));
    expect(notes, contains('6 pull requests.'));
    expect(notes, contains('- side change'));
    expect(notes, contains('- main change'));
    expect(notes, isNot(contains('merge side branch')));
  });
}
