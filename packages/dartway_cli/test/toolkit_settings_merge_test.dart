import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/project_layout.dart';
import 'package:dartway_cli/src/toolkit_installer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `.claude/settings.json` is the third kind of file the installer deals in: a
/// toolkit default the project extends, rather than one the toolkit owns
/// outright or one it has no opinion about.
///
/// It used to be treated as the project's, which meant a changed default
/// reached an existing project only if somebody deleted the file first — and a
/// new `deny` rule reached none of them at all, which is the half the harness is
/// supposed to enforce rather than merely state. What is pinned here is both
/// halves of the merge: the template's entries arrive, and the project's own
/// survive.
void main() {
  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_settings'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  ProjectLayout layoutIn(Directory root) => ProjectLayout(
    root: root,
    serverPackage: 'my_app_server',
    clientPackage: 'my_app_client',
    flutterPackage: 'my_app_flutter',
  );

  /// The minimum toolkit the installer insists on, plus the settings template
  /// under test.
  Directory writeToolkit(Map<String, dynamic> settings) {
    final toolkitDir = Directory(p.join(sandbox.path, 'toolkit'))
      ..createSync(recursive: true);
    Directory(p.join(toolkitDir.path, 'skills')).createSync();
    Directory(p.join(toolkitDir.path, 'commands')).createSync();
    File(p.join(toolkitDir.path, 'CLAUDE.md')).writeAsStringSync('harness\n');
    File(
      p.join(toolkitDir.path, 'settings.json'),
    ).writeAsStringSync(jsonEncode(settings));
    return toolkitDir;
  }

  var installCount = 0;

  Future<Directory> installInto(
    Directory? projectRoot,
    Map<String, dynamic> toolkitSettings,
  ) async {
    final root =
        projectRoot ??
        (Directory(p.join(sandbox.path, 'project${installCount++}'))
          ..createSync(recursive: true));
    await ToolkitInstaller.install(
      toolkitDir: writeToolkit(toolkitSettings),
      projectRoot: root,
      tokens: layoutIn(root).toolkitTokens(baseBranch: 'master'),
    );
    return root;
  }

  Map<String, dynamic> settingsIn(Directory root) =>
      jsonDecode(
            File(
              p.join(root.path, '.claude', 'settings.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<String> allowIn(Directory root) =>
      ((settingsIn(root)['permissions'] as Map<String, dynamic>)['allow']
              as List)
          .cast<String>();

  const seed = {
    'permissions': {
      'allow': ['Bash(dart test:*)'],
      'deny': ['Read(./**/config/passwords.yaml)'],
    },
  };

  test('a project with no settings gets the template as it stands', () async {
    final root = await installInto(null, seed);
    expect(allowIn(root), ['Bash(dart test:*)']);
  });

  test('a default added later reaches a project installed before it', () async {
    // The whole point. This used to require deleting the file by hand.
    final root = await installInto(null, seed);
    await installInto(root, {
      'permissions': {
        'allow': ['Bash(dart test:*)', 'Bash(flutter test:*)'],
        'deny': ['Read(./**/config/passwords.yaml)'],
      },
    });

    expect(allowIn(root), contains('Bash(flutter test:*)'));
  });

  test('a new deny rule reaches it too', () async {
    // The half that matters most: a deny rule is something the harness is meant
    // to enforce, and it used to reach no existing project at all.
    final root = await installInto(null, seed);
    await installInto(root, {
      'permissions': {
        'allow': ['Bash(dart test:*)'],
        'deny': ['Read(./**/config/passwords.yaml)', 'Read(./**/*.pem)'],
      },
    });

    final deny =
        ((settingsIn(root)['permissions'] as Map<String, dynamic>)['deny']
                as List)
            .cast<String>();
    expect(deny, contains('Read(./**/*.pem)'));
  });

  test('what the project added survives the update', () async {
    final root = await installInto(null, seed);
    final file = File(p.join(root.path, '.claude', 'settings.json'));
    file.writeAsStringSync(
      jsonEncode({
        'permissions': {
          'allow': ['Bash(dart test:*)', 'Bash(make deploy:*)'],
          'deny': ['Read(./**/config/passwords.yaml)'],
        },
        'model': 'opus',
      }),
    );

    await installInto(root, {
      'permissions': {
        'allow': ['Bash(dart test:*)', 'Bash(flutter test:*)'],
        'deny': ['Read(./**/config/passwords.yaml)'],
      },
    });

    expect(allowIn(root), contains('Bash(make deploy:*)'));
    expect(allowIn(root), contains('Bash(flutter test:*)'));
    // A key the template says nothing about is not the toolkit's to remove.
    expect(settingsIn(root)['model'], 'opus');
  });

  test('the project keeps its own value where the template has one', () async {
    final root = await installInto(null, seed);
    final file = File(p.join(root.path, '.claude', 'settings.json'));
    file.writeAsStringSync(
      jsonEncode({
        'permissions': {
          'allow': ['Bash(dart test:*)'],
          'deny': ['Read(./**/config/passwords.yaml)'],
        },
        'model': 'opus',
      }),
    );

    await installInto(root, {...seed, 'model': 'sonnet'});

    // The template seeds defaults; it does not overrule a decision already made.
    expect(settingsIn(root)['model'], 'opus');
  });

  test('a second install with nothing new changes nothing', () async {
    final root = await installInto(null, seed);
    final before = File(
      p.join(root.path, '.claude', 'settings.json'),
    ).readAsStringSync();

    await installInto(root, seed);

    expect(
      File(p.join(root.path, '.claude', 'settings.json')).readAsStringSync(),
      before,
    );
  });

  test('a file that is not valid JSON is left exactly as it was', () async {
    // An installer that rewrites something it could not read is worse than one
    // that skips it: the unreadable file is still the project's only copy.
    final root = await installInto(null, seed);
    final file = File(p.join(root.path, '.claude', 'settings.json'));
    const broken = '{ "permissions": { "allow": [ ';
    file.writeAsStringSync(broken);

    await installInto(root, seed);

    expect(file.readAsStringSync(), broken);
  });
}
