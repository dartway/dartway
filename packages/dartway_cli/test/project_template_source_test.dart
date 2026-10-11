import 'dart:io';

import 'package:dartway_cli/src/checker/dw_project_template.dart';
import 'package:dartway_cli/src/toolkit_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late Directory recordedCheckout;

  setUp(() {
    project = Directory.systemTemp.createTempSync('dw_template_project');
    recordedCheckout = Directory.systemTemp.createTempSync(
      'dw_recorded_checkout',
    );
    Directory(p.join(recordedCheckout.path, 'template')).createSync();
  });

  tearDown(() {
    if (recordedCheckout.existsSync()) {
      recordedCheckout.deleteSync(recursive: true);
    }
    project.deleteSync(recursive: true);
  });

  test('skips an unreadable path recorded on another machine', () {
    _writeManifest(project, recordedCheckout.path, commit: null);
    Process.runSync('chmod', ['000', recordedCheckout.path]);
    addTearDown(() {
      Process.runSync('chmod', ['700', recordedCheckout.path]);
    });

    final template = DwProjectTemplate.forProject(project, 'sample_app');

    expect(template, isNotNull);
    expect(template!.description, isNot(contains(recordedCheckout.path)));
    expect(template.fileFor('pubspec.yaml'), isNotNull);
  }, skip: _runsWithElevatedFileAccess());

  test('skips a recorded checkout that does not hold its recorded commit', () {
    _writeManifest(
      project,
      recordedCheckout.path,
      commit: List.filled(40, 'f').join(),
    );

    final template = DwProjectTemplate.forProject(project, 'sample_app');

    expect(template, isNotNull);
    expect(template!.description, isNot(contains(recordedCheckout.path)));
    expect(template.fileFor('pubspec.yaml'), isNotNull);
  });
}

void _writeManifest(
  Directory project,
  String source, {
  required String? commit,
}) {
  ToolkitProvenance(
    source: source,
    channel: null,
    commit: commit,
    cliVersion: 'test',
    installedAt: '2026-10-11T00:00:00.000Z',
  ).write(project);
}

bool _runsWithElevatedFileAccess() {
  if (Platform.isWindows) return true;
  return Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
}
