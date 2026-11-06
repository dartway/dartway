import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/commands/contract_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'baseline copies the generated descriptor beside the shared pubspec',
    () async {
      final root = Directory.systemTemp.createTempSync('dw_contract_baseline_');
      addTearDown(() => root.deleteSync(recursive: true));
      final shared = Directory(
        p.join(root.path, 'acme_shared', 'lib', 'generated'),
      )..createSync(recursive: true);
      File(
        p.join(root.path, 'acme_shared', 'pubspec.yaml'),
      ).writeAsStringSync('name: acme_shared\nversion: 0.4.2\n');
      final descriptor = {
        'format': 2,
        'codec': 1,
        'contractVersion': '0.4.2',
        'objects': <String, Object?>{},
        'unverified': <Object?>[],
      };
      File(
        p.join(shared.path, 'dw_contract.json'),
      ).writeAsStringSync(jsonEncode(descriptor));
      Process.runSync('git', ['init'], workingDirectory: root.path);
      Process.runSync('git', ['add', '.'], workingDirectory: root.path);
      Process.runSync('git', [
        '-c',
        'user.name=Test',
        '-c',
        'user.email=test@example.com',
        'commit',
        '-m',
        'base',
      ], workingDirectory: root.path);
      final previous = Directory.current;
      try {
        Directory.current = root;
        final runner = CommandRunner<int>('dartway', 'test')
          ..addCommand(ContractCommand());
        expect(await runner.run(['contract', 'baseline']), 0);
      } finally {
        Directory.current = previous;
      }
      expect(
        jsonDecode(
          File(
            p.join(root.path, 'acme_shared', 'contract_baseline.json'),
          ).readAsStringSync(),
        ),
        containsPair('baselineCommit', isNotEmpty),
      );
    },
  );
}
