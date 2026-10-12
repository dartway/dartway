import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  const revision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final harness = useHarness(
    build: (app, database) => app.server(
      database,
      settings: const DwServerSettings(deploymentVersion: revision),
    ),
  );

  for (final path in ['/health', '/dw/health']) {
    test(
      '$path reports the configured native revision without cacheability',
      () async {
        final answer = await harness().caller().raw('GET', path);
        expect(answer.status, 200);
        expect(answer.text, 'ok');
        expect(answer.headers.value(HttpHeaders.etagHeader), '"$revision"');
        expect(
          answer.headers.value(HttpHeaders.cacheControlHeader),
          'no-store',
        );
      },
    );
  }
  test('HEAD reports the same revision without a response body', () async {
    final answer = await harness().caller().raw('HEAD', '/dw/health');
    expect(answer.status, 200);
    expect(answer.text, isEmpty);
    expect(answer.headers.value(HttpHeaders.etagHeader), '"$revision"');
  });
}
