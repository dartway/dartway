import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('optional contract arguments use the bash 3.2 empty-array guard', () {
    final script = File('checks.sh').readAsStringSync();

    expect(
      script,
      contains(r'${contract_args[@]+"${contract_args[@]}"}'),
      reason: 'Bash before 4.4 treats an unguarded empty array as unset under '
          'set -u.',
    );
  });

  test('the guarded expansion accepts an empty array under nounset', () async {
    final result = await Process.run('/bin/bash', [
      '-uc',
      r'''
contract_args=()
set -- ${contract_args[@]+"${contract_args[@]}"}
printf '%s\n' "$#"
''',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, '0\n');
  });

  test('the guarded expansion keeps populated arguments quoted', () async {
    final result = await Process.run('/bin/bash', [
      '-uc',
      r'''
contract_args=(--contract-base "sha with spaces")
printf '<%s>\n' ${contract_args[@]+"${contract_args[@]}"}
''',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, '<--contract-base>\n<sha with spaces>\n');
  });
}
