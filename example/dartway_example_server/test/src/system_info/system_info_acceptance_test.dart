import 'dart:io';

import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness app;
  setUpAll(() async => app = await AppHarness.start());
  tearDownAll(() => app.stop());

  Future<void> exercise() async {
    final http = DwSeamCassette('test/cassettes/system_info_http.json');
    final process = DwSeamCassette('test/cassettes/system_info_process.json');
    app.server.http.reset();
    app.server.process.reset();
    app.server.http.useCassette(http);
    app.server.process.useCassette(process);
    final anonymous = app.server.caller();
    addTearDown(anonymous.close);
    expect((await anonymous.raw('GET', '/system-info')).status, 401);
    expect(app.server.http.requests, isEmpty);
    expect(app.server.process.requests, isEmpty);
    final answer = await app.systemInfo();
    expect(answer.status, 200);
    expect((answer.json as Map)['message'], isNotEmpty);
    expect((answer.json as Map)['gitVersion'], startsWith('git version '));
    http.verifyComplete();
    process.verifyComplete();
  }

  test('replays real GitHub and git answers offline', exercise);
  test(
    'checks external response shapes',
    exercise,
    tags: 'seam',
    skip: Platform.environment['DW_VERIFY_SEAMS'] != '1',
  );
}
