import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_setup.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// `setup`'s own data-volume guard, wired the same way `deploy_runner_test`
/// wires `checkDataVolumes` — the case a change to either wiring, or to
/// `judgeDataVolumes` itself, should turn red.
void main() {
  final args = DeploySetupCommand().argParser.parse(['--env', 'staging']);

  test('the BBR provisioning script is valid POSIX shell', () async {
    final syntax = await Process.run('dash', ['-n', '-c', dwBbrSetupScript]);
    expect(syntax.exitCode, 0, reason: '${syntax.stderr}');
  });

  test('the BBR configuration writes are idempotent', () async {
    final root = Directory.systemTemp.createTempSync('dw_bbr_setup_');
    addTearDown(() => root.deleteSync(recursive: true));
    final modules = File('${root.path}/dartway-bbr.conf');
    final sysctl = File('${root.path}/90-dartway-net.conf');
    final writes = dwBbrSetupScript
        .replaceAll('/etc/modules-load.d/dartway-bbr.conf', modules.path)
        .replaceAll('/etc/sysctl.d/90-dartway-net.conf', sysctl.path)
        .replaceFirst(RegExp(r'modprobe tcp_bbr[^\n]*\n'), '')
        .replaceFirst(RegExp(r'if ! grep[\s\S]*?fi\n'), '')
        .replaceFirst(RegExp(r'sysctl -p[^\n]+\n'), '');

    // Modification times through Dart: GNU `stat --format` is not on macOS.
    Future<String> stat() async =>
        '${(await modules.stat()).modified.microsecondsSinceEpoch}:'
        '${(await sysctl.stat()).modified.microsecondsSinceEpoch}';

    final first = await Process.run('dash', ['-c', writes]);
    expect(first.exitCode, 0, reason: '${first.stderr}');
    final before = await stat();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await Process.run('dash', ['-c', writes]);
    expect(second.exitCode, 0, reason: '${second.stderr}');

    expect(modules.readAsStringSync(), 'tcp_bbr\n');
    expect(
      sysctl.readAsStringSync(),
      'net.core.default_qdisc=fq\n'
      'net.ipv4.tcp_congestion_control=bbr\n',
    );
    expect(await stat(), before, reason: 'the second run must not rewrite');
  });

  test('refuses before writing anything when the guard fails', () async {
    final ssh = RecordingSsh([
      (
        'docker volume ls',
        const DwSshResult(
          exitCode: 0,
          stdout: 'shop_postgres_data\nshop_minio_data\n',
          stderr: '',
        ),
      ),
    ]);
    final exitCode = await runSetup(
      stackVariants()['bundled storage and a site']!,
      args,
      connection: ssh,
    );
    expect(exitCode, 1);
    // Nothing past the guard ran: no compose file, no nginx configuration.
    expect(ssh.issued.any((c) => c.contains('docker-compose.yml')), isFalse);
  });

  test(
    'passes the guard and proceeds when the volume is already there',
    () async {
      final ssh = RecordingSsh([
        (
          'docker volume ls',
          const DwSshResult(
            exitCode: 0,
            stdout: 'shop_postgres_data\nshop_storage_data\n',
            stderr: '',
          ),
        ),
      ]);
      final exitCode = await runSetup(
        stackVariants()['bundled storage and a site']!,
        args,
        connection: ssh,
      );
      expect(exitCode, 0);
      expect(ssh.issued.any((c) => c.contains('docker-compose.yml')), isTrue);
      final bbr = ssh.issued.singleWhere(
        (command) => command.contains('/etc/modules-load.d/dartway-bbr.conf'),
      );
      expect(bbr, contains('modprobe tcp_bbr'));
      expect(bbr, contains('modprobe tcp_bbr 2>/dev/null || true'));
      expect(bbr, contains('tcp_allowed_congestion_control'));
      expect(bbr, contains('net.core.default_qdisc=fq'));
      expect(bbr, contains('net.ipv4.tcp_congestion_control=bbr'));
      expect(bbr, contains('sysctl -p /etc/sysctl.d/90-dartway-net.conf'));
    },
  );
}
