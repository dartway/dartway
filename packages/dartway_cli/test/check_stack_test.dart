@Tags(['docker'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // Build deploy/check/Dockerfile and supply its tag. The real image and entry
  // point run against a checkout mounted read-only, with no package cache.
  final image = Platform.environment['DW_CHECK_STACK_IMAGE'];
  for (final storage in ['bundled', 'external']) {
    for (final destination in ['stage', 'prod']) {
      test(
        '$destination selects its probes for $storage storage on a read-only mount',
        () async {
          expect(
            image,
            isNotNull,
            reason: 'Set DW_CHECK_STACK_IMAGE to the built deploy/check image.',
          );
          final source = Directory('test/fixtures/check_stack/$storage');
          final fixture = Directory.systemTemp.createTempSync(
            'dw-check-stack-',
          );
          addTearDown(() => fixture.deleteSync(recursive: true));
          for (final file
              in source.listSync(recursive: true).whereType<File>()) {
            final relative = p
                .relative(file.path, from: source.path)
                .replaceFirst(RegExp(r'\.fixture$'), '');
            final target = File(p.join(fixture.path, relative));
            target.parent.createSync(recursive: true);
            file.copySync(target.path);
          }
          final result = await Process.run('docker', [
            'run',
            '--rm',
            '-v',
            '${fixture.path}:/project:ro',
            image!,
            '--env',
            destination,
          ]);
          // .invalid hosts intentionally have no deployment. Each selected probe
          // must run and report its own failure; none can silently skip.
          expect(result.exitCode, 1, reason: '${result.stderr}');
          expect(result.stderr, isEmpty);
          final output = result.stdout as String;
          final lines = output.trim().split('\n');
          expect(lines.length, storage == 'bundled' ? 9 : 6, reason: output);
          expect(
            lines.every((line) => line.startsWith('FAIL')),
            true,
            reason: output,
          );
          expect(output, contains('https://api.$destination.invalid/health'));
          expect(output, contains('https://app.$destination.invalid/health'));
          expect(output, contains('wss://api.$destination.invalid/dw/live'));
          expect(output, contains('wss://app.$destination.invalid/dw/live'));
          expect(output, contains('GET https://app.$destination.invalid/'));
          expect(
            output,
            contains('cache policy of https://app.$destination.invalid'),
          );
          final other = destination == 'stage' ? 'prod' : 'stage';
          expect(output, isNot(contains('.$other.invalid')));
          if (storage == 'bundled') {
            expect(
              output,
              contains(
                'anonymous GET of https://files.$destination.invalid/{probe-public,probe-private}',
              ),
            );
            for (final bucket in ['public', 'private']) {
              expect(
                output,
                contains(
                  'preflight PUT https://files.$destination.invalid/probe-$bucket/dw-cors-probe from https://app.$destination.invalid',
                ),
              );
            }
          } else {
            expect(output, isNot(contains('anonymous GET')));
            expect(output, isNot(contains('preflight PUT')));
          }
          // Docker enforces the mount's mode, independently of the host's umask.
          final write = await Process.run('docker', [
            'run',
            '--rm',
            '--entrypoint',
            '/bin/sh',
            '-v',
            '${fixture.path}:/project:ro',
            image,
            '-c',
            'touch /project/must-not-write',
          ]);
          expect(write.exitCode, isNot(0));
          expect(write.stderr, contains('Read-only file system'));
          expect(
            File(p.join(fixture.path, 'must-not-write')).existsSync(),
            false,
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
