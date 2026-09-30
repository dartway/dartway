import 'dart:async';
import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_shared_layout.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The shared package mirrors the server's features (#383). Every rule has a
/// case that passes and one that fails.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_shared_layout');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// A project whose server has [features] and whose shared package holds
  /// [files] under `lib/` — a folder for a path ending in `/` — and the
  /// inspector's verdict on it.
  DwSharedLayoutInspector inspect(
    Map<String, String> files, {
    List<String>? features = const ['chat', 'issues', 'profile'],
    DwCheckType? filterType,
  }) {
    final shared = Directory(p.join(sandbox.path, 'acme_shared'));
    File(p.join(shared.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: acme_shared\n');
    for (final MapEntry(key: path, value: source) in {
      'acme_shared.dart': '',
      ...files,
    }.entries) {
      final full = p.join(shared.path, 'lib', path);
      if (path.endsWith('/')) {
        Directory(full).createSync(recursive: true);
      } else {
        File(full)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(source);
      }
    }
    Directory? server;
    if (features != null) {
      server = Directory(p.join(sandbox.path, 'acme_server'));
      for (final folder in [...features, 'core', 'migrations']) {
        Directory(
          p.join(server.path, 'lib', 'src', folder),
        ).createSync(recursive: true);
      }
    }
    final inspector = DwSharedLayoutInspector(
      sharedPackageDir: shared,
      serverPackageDir: server,
      filterType: filterType,
    );
    inspector.run();
    return inspector;
  }

  test('feature files, feature folders, parts and the project-named files '
      'pass', () {
    final inspector = inspect({
      'generated/dw_protocol.dart': '',
      'src/profile.dart': '',
      'src/profile.dw.dart': '',
      'src/chat/chat.dart': '',
      'src/chat/chat.dw.dart': '',
      'src/chat/chat_messages.dart': '',
      'src/issues/issues_comments.dart': '',
      'src/issues/issues_process_rules.dart': '',
      'src/acme_channel.dart': '',
      'src/acme_refusal.dart': '',
      'src/acme_upload.dart': '',
      'src/acme_protocol.dart': '',
      'src/acme_push_category.dart': '',
    });
    expect(inspector.findings, isEmpty);
  });

  test('a file named after no server feature fails, with its owner named', () {
    final inspector = inspect({
      'src/issue_process.dart': '',
      'src/notifications.dart': '',
    });
    expect(inspector.findings, hasLength(2));
    expect(
      inspector.findings.first,
      allOf(
        contains('src/issue_process.dart'),
        contains('src/issues/issues_process.dart'),
      ),
    );
    expect(
      inspector.findings.last,
      allOf(
        contains('src/notifications.dart'),
        contains('chat, issues, profile'),
      ),
    );
  });

  test('a near miss of a feature name is told the name', () {
    final inspector = inspect({'src/issue.dart': ''});
    expect(inspector.findings.single, contains('rename it to src/issues.dart'));
  });

  test('a protocol file not named after the package is told its name', () {
    final inspector = inspect({
      'src/app_protocol.dart': '',
      'src/acme_wire_protocol.dart': '',
    });
    expect(inspector.findings, hasLength(2));
    for (final finding in inspector.findings) {
      expect(finding, contains('rename it to acme_protocol.dart'));
    }
  });

  test('another project-named file fails', () {
    final inspector = inspect({'src/acme_enums.dart': ''});
    expect(
      inspector.findings.single,
      contains('the project-named files are acme_channel.dart'),
    );
  });

  test('a folder named after no server feature fails', () {
    final inspector = inspect({'src/models/': '', 'src/coach/coach.dart': ''});
    expect(inspector.findings, hasLength(2));
    expect(inspector.findings.first, contains('src/coach/'));
    expect(inspector.findings.last, contains('src/models/'));
  });

  test('a feature as a file and a folder at once fails', () {
    final inspector = inspect({
      'src/profile.dart': '',
      'src/profile/profile_consents.dart': '',
    });
    expect(
      inspector.findings.single,
      allOf(
        contains('src/profile.dart beside'),
        contains('src/profile/profile.dart'),
      ),
    );
  });

  test('inside a feature folder: another prefix, a layer part and a '
      'subfolder fail', () {
    final inspector = inspect({
      'src/chat/chat.dart': '',
      'src/chat/enums.dart': '',
      'src/chat/chat_models.dart': '',
      'src/chat/messages/': '',
    });
    expect(inspector.findings, hasLength(3));
    expect(inspector.findings[0], contains('chat_models.dart'));
    expect(inspector.findings[1], contains('rename it to chat_enums.dart'));
    expect(inspector.findings[2], contains('is flat'));
  });

  test('lib/ holds the library, generated/ and src/', () {
    final inspector = inspect({'helpers.dart': '', 'models/': ''});
    expect(inspector.findings, hasLength(2));
    expect(inspector.findings.first, contains('acme_shared/lib/helpers.dart'));
  });

  test('without a server package names are not matched, and it says so', () {
    final lines = <String>[];
    late DwSharedLayoutInspector inspector;
    runZonedPrint(
      () => inspector = inspect({'src/anything.dart': ''}, features: null),
      lines,
    );
    expect(inspector.findings, isEmpty);
    expect(lines.join('\n'), contains('not matched to server features'));
  });

  test('another --type turns it off', () {
    final inspector = inspect({
      'src/notifications.dart': '',
    }, filterType: DwCheckType.fileLong);
    expect(inspector.findings, isEmpty);
  });

  test('the template and the example pass', () {
    final root = p.normalize(p.join(Directory.current.path, '..', '..'));
    for (final (project, prefix) in [
      ('template', 'dartway_starter'),
      ('example', 'dartway_example'),
    ]) {
      final inspector = DwSharedLayoutInspector(
        sharedPackageDir: Directory(p.join(root, project, '${prefix}_shared')),
        serverPackageDir: Directory(p.join(root, project, '${prefix}_server')),
      );
      inspector.run();
      expect(inspector.findings, isEmpty, reason: project);
    }
  });
}

/// Runs [body] with its `print`s collected in [lines].
void runZonedPrint(void Function() body, List<String> lines) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) => lines.add(line),
  ),
);
