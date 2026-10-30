import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      settings: const DwServerSettings(alertsPerMinute: 100),
    ),
  );

  Map<String, Object?> report({String device = 'device-1'}) => {
    'deviceId': device,
    'errorType': 'StateError',
    'error': 'StateError: broken',
    'stackTrace':
        '#0 dart:core-patch/noise\n#1 package:flutter/noise\n#2 package:dartway_core_flutter/noise\n#3 package:app/feature.dart:42',
    'platform': 'android',
    'appVersion': '1.2.3+4',
    'route': '/checkout',
    'featureIds': ['checkout'],
    'entries': {'account': 'forged', 'tenant': 'north'},
    'count': 2,
  };

  Future<DwTestAnswer> send(Map<String, Object?> value, {String? token}) =>
      harness()
          .caller(token: token)
          .raw(
            'POST',
            DwHttpContract.clientErrorPath,
            headers: {
              'content-type': 'application/json',
              if (token != null)
                'authorization': '${DwHttpContract.bearerPrefix}$token',
            },
            body: utf8.encode(jsonEncode(value)),
          );

  test(
    'valid anonymous reports enter alerts with server-derived context and signature',
    () async {
      final answer = await send(report());
      expect(answer.status, 204);
      await eventually(() => harness().app.alerts.incidents.isNotEmpty);
      final incident = harness().app.alerts.incidents.last;
      expect(incident.where, 'client android /checkout');
      expect(incident.accountId, isNull);
      expect('${incident.error}', contains('tenant: north'));
      expect('${incident.error}', isNot(contains('account: forged')));
      expect(
        incident.signature,
        'client|android|StateError|package:app/feature.dart:42',
      );
      expect(incident.signature, isNot(startsWith('command ')));
    },
  );

  test('field caps and device rate limits are enforced', () async {
    final oversized = report()..['route'] = List.filled(513, 'x').join();
    expect((await send(oversized)).status, 400);
    for (var i = 0; i < 30; i++) {
      expect((await send(report(device: 'limited'))).status, 204);
    }
    expect((await send(report(device: 'limited'))).status, 429);
  });

  test('dart2js types and an empty or missing stack are accepted', () async {
    final web = report(device: 'web')
      ..['errorType'] = 'minified:Xy<Foo>'
      ..remove('stackTrace');
    expect((await send(web)).status, 204);
    await eventually(
      () => harness().app.alerts.incidents.any(
        (incident) => incident.signature == 'client|android|minified:Xy<Foo>|',
      ),
    );
  });

  test('authenticated reports use the server account', () async {
    final (_, session) = await harness().signedIn('reporter@example.com');
    final answer = await send(
      report(device: 'authenticated'),
      token: session.token,
    );
    expect(answer.status, 204);
    await eventually(
      () => harness().app.alerts.incidents.any(
        (incident) => incident.accountId == session.id,
      ),
    );
  });

  test('rotating device ids cannot bypass the peer limit', () async {
    var rejected = false;
    for (var i = 0; i < 100; i++) {
      final answer = await send(report(device: 'rotated-$i'));
      if (answer.status == 429) {
        rejected = true;
        break;
      }
    }
    expect(rejected, isTrue);
  });
}
