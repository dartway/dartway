import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

import 'support/test_app.dart';

void main() {
  const quota = DwCallRateLimit(requests: 30, burst: 1, maxPeers: 3);

  for (final trusted in [false, true]) {
    group(
      trusted ? 'explicit trusted ingress' : 'untrusted forwarding headers',
      () {
        final clock = DwTestClock(DateTime.utc(2026));
        final harness = useHarness(
          build: (app, config) => app.server(
            config,
            clock: clock,
            settings: DwServerSettings(
              callRateLimits: const {ListNotes: quota},
              trustedProxyNetworks: trusted
                  ? const ['127.0.0.1/32', '172.18.0.0/16']
                  : const [],
              behindProxy: trusted,
            ),
          ),
        );

        setUp(() => clock.advance(const Duration(minutes: 2)));

        Future<DwTestAnswer> call(String forwarded) => harness().caller().call(
          const ListNotes(ownerId: -1),
          headers: {'x-forwarded-for': forwarded},
        );

        test(
          'burst is bounded, retries do not reset it, and it refills',
          () async {
            expect((await call('198.51.100.10')).status, 200);
            expect((await call('198.51.100.10')).status, 200);
            final blocked = await call('198.51.100.10');
            expect(blocked.status, 429);
            expect(
              blocked.refusal.isCode(DwCoreRefusal.tooManyRequests),
              isTrue,
            );
            expect(blocked.headers.value('retry-after'), '2');
            expect((await call('198.51.100.10')).status, 429);
            clock.advance(const Duration(milliseconds: 1999));
            expect((await call('198.51.100.10')).status, 429);
            clock.advance(const Duration(milliseconds: 1));
            expect((await call('198.51.100.10')).status, 200);
          },
        );

        test(
          'changing a client-supplied prefix cannot bypass the limit',
          () async {
            expect(
              (await call('203.0.113.1, 198.51.100.10, 172.18.0.5')).status,
              200,
            );
            expect(
              (await call('203.0.113.2, 198.51.100.10, 172.18.0.5')).status,
              200,
            );
            expect(
              (await call('203.0.113.3, 198.51.100.10, 172.18.0.5')).status,
              429,
            );
          },
        );

        test(
          'peer separation requires trusted transport, not just a header',
          () async {
            await call('198.51.100.10');
            await call('198.51.100.10');
            expect((await call('198.51.100.11')).status, trusted ? 200 : 429);
          },
        );

        test(
          'other calls and compatibility checks retain their outcomes',
          () async {
            await call('198.51.100.10');
            await call('198.51.100.10');
            final caller = harness().caller();
            final incompatible = await caller.call(
              const ListNotes(ownerId: -1),
              headers: {
                DwHttpContract.protocolHeader: '${dwProtocolVersion + 1}',
              },
            );
            expect(incompatible.status, 426);
            expect((await caller.call(const GetNote(-1))).status, 404);
          },
        );

        test('concurrent requests share one quota', () async {
          final answers = await Future.wait([
            for (var index = 0; index < 8; index++) call('198.51.100.10'),
          ]);
          expect(answers.where((answer) => answer.status == 200), hasLength(2));
          expect(answers.where((answer) => answer.status == 429), hasLength(6));
        });

        test('moving the clock back cannot replenish a quota', () async {
          final start = clock.now();
          await call('198.51.100.10');
          await call('198.51.100.10');
          clock.moveTo(start.subtract(const Duration(seconds: 1)));
          expect((await call('198.51.100.10')).status, 429);
          clock.moveTo(start.add(const Duration(seconds: 2)));
          expect((await call('198.51.100.10')).status, 200);
        });

        if (!trusted) {
          test(
            'a blocked slow body is answered before its bytes arrive',
            () async {
              await call('198.51.100.10');
              await call('198.51.100.10');
              final caller = harness().caller();
              final socket = await Socket.connect(
                caller.base.host,
                caller.base.port,
              );
              addTearDown(socket.destroy);
              socket.write(
                [
                  'POST /dw/ListNotes HTTP/1.1',
                  'Host: ${caller.base.host}',
                  '${DwHttpContract.protocolHeader}: $dwProtocolVersion',
                  if (caller.protocol.contractVersion case final version?)
                    '${DwHttpContract.contractVersionHeader}: ${version.text}',
                  'Content-Type: application/json',
                  'Content-Length: 100000',
                  '',
                  '',
                ].join('\r\n'),
              );
              await socket.flush();
              final answer = await utf8.decoder
                  .bind(socket)
                  .join()
                  .timeout(const Duration(seconds: 2));
              expect(answer, startsWith('HTTP/1.1 429 '));
            },
          );
        }

        if (trusted) {
          for (final peer in [
            ['198.51.100.10', '::ffff:198.51.100.10', '198.51.100.10'],
            ['2001:db8::a', '2001:0db8:0:0:0:0:0:a', '2001:DB8::A'],
          ]) {
            test('address spellings share one quota: ${peer.first}', () async {
              expect((await call(peer[0])).status, 200);
              expect((await call(peer[1])).status, 200);
              expect((await call(peer[2])).status, 429);
            });
          }
          test(
            'full state refuses new peers without evicting active quotas',
            () async {
              for (final peer in [
                '198.51.100.1',
                '198.51.100.2',
                '198.51.100.3',
              ]) {
                await call(peer);
                await call(peer);
              }
              expect((await call('198.51.100.4')).status, 429);
              expect((await call('198.51.100.1')).status, 429);
              clock.advance(const Duration(seconds: 4));
              expect((await call('198.51.100.4')).status, 200);
            },
          );

          test(
            'malformed forwarding cannot create arbitrary quota keys',
            () async {
              await call('invalid');
              await call('unknown');
              expect((await call('not-an-address')).status, 429);
            },
          );
        }
      },
    );
  }
}
