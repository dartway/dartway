import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  const limit = DwCallRateLimit(requests: 30, burst: 1);

  for (final trusted in [false, true]) {
    group(trusted ? 'trusted proxy' : 'untrusted peer', () {
      final clock = DwTestClock(DateTime.utc(2026));
      var handled = 0;
      final harness = useHarness(
        build: (app, config) => app.server(
          config,
          clock: clock,
          settings: DwServerSettings(
            behindProxy: trusted,
            trustedProxyNetworks: trusted
                ? const ['127.0.0.1/32', '::1/128']
                : const [],
          ),
          routes: [
            DwHttpRoute.post('/register', (ctx, request) {
              handled++;
              return DwHttpResponse.empty(status: 201);
            }, rateLimit: limit),
          ],
        ),
      );

      setUp(() {
        handled = 0;
        clock.advance(const Duration(minutes: 2));
      });

      Future<DwTestAnswer> request(String forwarded) => harness().caller().raw(
        'POST',
        '/register',
        headers: {'x-forwarded-for': forwarded},
      );

      test('the trusted boundary selects the peer quota key', () async {
        expect((await request('198.51.100.10')).status, 201);
        expect((await request('198.51.100.10')).status, 201);
        final other = await request('198.51.100.11');
        expect(other.status, trusted ? 201 : 429);
      });

      test(
        'over quota returns the call refusal without running handler',
        () async {
          await request('198.51.100.10');
          await request('198.51.100.10');
          final refused = await request('198.51.100.10');
          expect(refused.status, 429);
          expect(refused.headers.value('retry-after'), '2');
          expect(refused.refusal.isCode(DwCoreRefusal.tooManyRequests), isTrue);
          expect(handled, 2);
        },
      );
    });
  }
}
