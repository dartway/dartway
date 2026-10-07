import 'dart:io';
import 'package:args/args.dart';
import 'package:dartway_cli/src/toolkit_install.dart';
import 'package:dartway_cli/src/toolkit_installer.dart';
import 'package:dartway_cli/src/toolkit_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root, source;
  File file(String name) => File(p.join(root.path, name));
  Future<void> install(String agent) => ToolkitInstaller.install(
    toolkitDir: source,
    projectRoot: root,
    tokens: {'__SERVER_PKG__': 'sample_server'},
    agent: agent,
  );
  setUp(() {
    root = Directory.systemTemp.createTempSync('dw-agents-');
    source = Directory(p.join(root.path, 'source'))..createSync();
    File(
      p.join(source.path, 'AGENTS.md'),
    ).writeAsStringSync('__SERVER_PKG__ rules');
    Directory(p.join(source.path, 'commands')).createSync();
    final skill = File(p.join(source.path, 'skills/dartway-server/SKILL.md'));
    skill.parent.createSync(recursive: true);
    skill.writeAsStringSync('__SERVER_PKG__ skill');
  });
  tearDown(() => root.deleteSync(recursive: true));
  test(
    'reinstall preserves owner rules and installs identical skill copies',
    () async {
      file(
        'AGENTS.md',
      ).writeAsStringSync('<!-- aios-managed -->\nOwner rules  \n\n');
      file('CLAUDE.md').writeAsStringSync('Project rules\n');
      await install('both');
      final first = file('AGENTS.md').readAsStringSync();
      await install('both');
      expect(file('AGENTS.md').readAsStringSync(), first);
      expect(first, startsWith('<!-- aios-managed -->\nOwner rules  \n\n'));
      expect(file('CLAUDE.md').readAsStringSync(), startsWith('Project rules'));
      expect(
        file('.agents/DARTWAY.md').readAsStringSync(),
        'sample_server rules',
      );
      expect(
        file('.agents/skills/dartway-server/SKILL.md').readAsStringSync(),
        file('.claude/skills/dartway-server/SKILL.md').readAsStringSync(),
      );
    },
  );
  test(
    'switch removes only managed integration, retaining custom skills',
    () async {
      await install('both');
      final custom = file('.claude/skills/local/SKILL.md');
      custom.parent.createSync(recursive: true);
      custom.writeAsStringSync('local');
      file(
        'CLAUDE.md',
      ).writeAsStringSync('owner\n${file('CLAUDE.md').readAsStringSync()}');
      await install('codex');
      expect(
        file('.claude/skills/dartway-server/SKILL.md').existsSync(),
        isFalse,
      );
      expect(custom.readAsStringSync(), 'local');
      expect(file('CLAUDE.md').readAsStringSync(), contains('owner'));
      expect(
        file('CLAUDE.md').readAsStringSync(),
        isNot(contains('dartway-toolkit:start')),
      );
      await install('claude');
      expect(
        file('.agents/skills/dartway-server/SKILL.md').existsSync(),
        isFalse,
      );
      expect(
        file('.claude/skills/dartway-server/SKILL.md').existsSync(),
        isTrue,
      );
    },
  );
  test('malformed block refuses before writing anything', () async {
    const text = 'owner\n<!-- dartway-toolkit:start -->';
    file('AGENTS.md').writeAsStringSync(text);
    await expectLater(install('both'), throwsStateError);
    expect(file('.agents/DARTWAY.md').existsSync(), isFalse);
    expect(file('AGENTS.md').readAsStringSync(), text);
  });
  test('update remembers agent choice and explicit flag overrides it', () {
    final parser = ArgParser();
    addToolkitInstallOptions(parser, defaultChannel: 'stable');
    const installed = ToolkitProvenance(
      source: 'test',
      channel: null,
      commit: null,
      cliVersion: 'test',
      installedAt: 'test',
      settings: {'agent': 'codex'},
    );
    expect(
      ToolkitInstallChoice.resolve(
        args: parser.parse([]),
        installed: installed,
      ).agent,
      'codex',
    );
    expect(
      ToolkitInstallChoice.resolve(
        args: parser.parse(['--agent', 'both']),
        installed: installed,
      ).agent,
      'both',
    );
    expect(
      ToolkitInstallChoice.resolve(
        args: parser.parse([]),
        installed: null,
      ).agent,
      'both',
    );
  });
  test('reads old manifest and writes common manifest', () {
    final legacy = file('.claude/dartway-toolkit.json');
    legacy.parent.createSync(recursive: true);
    legacy.writeAsStringSync(
      '{"source":"legacy","settings":{"agent":"claude"}}',
    );
    final installed = ToolkitProvenance.read(root)!;
    installed.write(root);
    expect(file('.agents/dartway-toolkit.json').existsSync(), isTrue);
    legacy.writeAsStringSync('invalid');
    expect(ToolkitProvenance.read(root)!.source, 'legacy');
  });
}
