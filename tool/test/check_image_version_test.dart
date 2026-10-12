import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final script = p.absolute('tag_check_image.sh');
  late Directory root;

  void write(String name, String text, {bool executable = false}) {
    final file = File(p.join(root.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
    if (executable) Process.runSync('chmod', ['+x', file.path]);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('check-image-version-');
    write('packages/dartway_cli/pubspec.yaml', 'version: 0.24.0\n');
    write('bin/git', '#!/bin/sh\necho framework-sha\n', executable: true);
    write('bin/curl', r'''#!/bin/sh
if [ "$MISSING_VERSION" = true ]; then exit 22; fi
echo '{"version":"0.24.0"}'
''', executable: true);
    write(
      'bin/jq',
      "#!/bin/sh\ncat >/dev/null\necho 0.24.0\n",
      executable: true,
    );
    write('bin/docker', r'''#!/bin/sh
echo "$*" >> docker-calls
if [ "$3" = create ]; then touch created; exit 0; fi
case "$4" in
  *:framework-sha|*@sha256:source) echo sha256:source ;;
  *:0.24.0)
    if [ -f created ]; then echo sha256:source
    elif [ "$EXISTING" = absent ]; then echo 'manifest unknown' >&2; exit 1
    elif [ "$EXISTING" = denied ]; then echo 'unauthorized' >&2; exit 1
    else echo "$EXISTING"; fi ;;
  *) exit 2 ;;
esac
''', executable: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run({
    String mode = 'publish',
    String existing = 'absent',
    bool missingVersion = false,
  }) => Process.runSync(
    '/bin/bash',
    [script, mode],
    workingDirectory: root.path,
    environment: {
      'PATH': '${p.join(root.path, 'bin')}:${Platform.environment['PATH']}',
      'EXISTING': existing,
      'MISSING_VERSION': '$missingVersion',
    },
  );

  test('copy by digest without rebuilding or wrapping a single manifest', () {
    final result = run();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final calls = File(p.join(root.path, 'docker-calls')).readAsStringSync();
    expect(
      calls,
      contains(
        'create --prefer-index=false --tag ghcr.io/dartway/dartway-check:0.24.0 ghcr.io/dartway/dartway-check@sha256:source',
      ),
    );
    expect(calls, isNot(contains('build ')));
  });

  test('existing matching version is never pushed again', () {
    expect(run(existing: 'sha256:source').exitCode, 0);
    expect(File(p.join(root.path, 'created')).existsSync(), false);
  });

  test('existing published version is skipped even at a different SHA', () {
    final result = run(existing: 'sha256:other');
    expect(result.exitCode, 0);
    expect(result.stdout, contains('already published; skipping'));
    expect(File(p.join(root.path, 'created')).existsSync(), false);
    expect(
      File(p.join(root.path, 'docker-calls')).readAsStringSync(),
      isNot(contains(':framework-sha')),
    );
  });

  test('registry failure is not treated as an absent tag', () {
    expect(run(existing: 'denied').exitCode, 1);
    expect(File(p.join(root.path, 'created')).existsSync(), false);
  });

  test('stable without a publication fails before accessing registry', () {
    final result = run(missingVersion: true);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('after publishing'));
    expect(File(p.join(root.path, 'docker-calls')).existsSync(), false);
  });

  test('prereleases are skipped', () {
    write('packages/dartway_cli/pubspec.yaml', 'version: 0.25.0-dev.1\n');
    expect(run().exitCode, 0);
    expect(File(p.join(root.path, 'docker-calls')).existsSync(), false);
  });

  test('PR dry run prints promotion and never contacts registry', () {
    final result = run(mode: 'dry-run');
    expect(result.exitCode, 0);
    expect(result.stdout, contains('Would verify pub.dev'));
    expect(result.stdout, contains('No images will be pushed'));
    expect(File(p.join(root.path, 'docker-calls')).existsSync(), false);
  });
}
