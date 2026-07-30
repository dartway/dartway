import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:test/test.dart';

void main() {
  group('check declarations', () {
    test('every id is unique', () {
      final ids = [
        ...dwLocalDeployChecks,
        ...dwRemoteDeployChecks,
      ].map((check) => check.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('local checks are local and remote checks are remote', () {
      expect(
        dwLocalDeployChecks.every((c) => c.stage == DwDeployCheckStage.local),
        isTrue,
      );
      expect(
        dwRemoteDeployChecks.every((c) => c.stage == DwDeployCheckStage.remote),
        isTrue,
      );
    });

    test('only remote checks can require SSH', () {
      expect(dwLocalDeployChecks.any((c) => c.requiresSsh), isFalse);
    });

    // A deployment does not read the local master file, and on CI that file is
    // absent by design. Including this check would put a warning in every run.
    test('the master-file check is not part of a deployment', () {
      final check = dwLocalDeployChecks.firstWhere(
        (c) => c.id == 'passwords-covers-environment',
      );
      expect(check.partOfDeploy, isFalse);
    });

    test('everything else is part of a deployment', () {
      final excluded = dwLocalDeployChecks
          .where((c) => !c.partOfDeploy)
          .map((c) => c.id)
          .toList();
      expect(excluded, ['passwords-covers-environment']);
    });
  });
}
