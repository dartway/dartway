import 'package:dartway_auth_providers_server/dartway_auth_providers_server.dart';
import 'package:test/test.dart';

import 'fixtures/provider_tokens.dart';
import 'support/fake_key_set.dart';

/// How the keys a provider publishes are held: long enough not to ask on
/// every sign-in, and not so long that a rotation locks everybody out.
void main() {
  late DateTime now;
  setUp(() => now = DateTime.utc(2031));

  DwJwksCache cacheOf(
    FakeKeySet keys, {
    Duration gap = const Duration(minutes: 1),
    Duration fallback = const Duration(hours: 1),
    Duration maximum = const Duration(hours: 24),
  }) => DwJwksCache(
    Uri.https('appleid.apple.com', '/auth/keys'),
    fetch: keys.fetch,
    minimumRefreshGap: gap,
    fallbackLifetime: fallback,
    maximumLifetime: maximum,
    now: () => now,
  );

  test('asks the provider once and then answers from what it holds', () async {
    final keys = FakeKeySet(appleJwks);
    final cache = cacheOf(keys);
    expect((await cache.keysFor('ec-1')).single.kid, 'ec-1');
    now = now.add(const Duration(minutes: 30));
    expect((await cache.keysFor('ec-1')).single.kid, 'ec-1');
    expect(keys.fetches, 1);
  });

  test('asks again when what the provider said it may hold has run out',
      () async {
    final keys = FakeKeySet(appleJwks, maxAge: const Duration(minutes: 10));
    final cache = cacheOf(keys);
    await cache.keysFor('ec-1');
    now = now.add(const Duration(minutes: 9));
    await cache.keysFor('ec-1');
    expect(keys.fetches, 1, reason: 'still within the provider’s max-age');
    now = now.add(const Duration(minutes: 2));
    await cache.keysFor('ec-1');
    expect(keys.fetches, 2);
  });

  test('holds a set no longer than the maximum, whatever the provider says',
      () async {
    final keys = FakeKeySet(appleJwks, maxAge: const Duration(days: 30));
    final cache = cacheOf(keys, maximum: const Duration(hours: 2));
    await cache.keysFor('ec-1');
    now = now.add(const Duration(hours: 3));
    await cache.keysFor('ec-1');
    expect(keys.fetches, 2);
  });

  test('a key id it does not hold sends it back to the provider — that is '
      'what a rotation looks like from here', () async {
    final keys = FakeKeySet(googleJwks);
    final cache = cacheOf(keys);
    expect(await cache.keysFor('ec-1'), isEmpty);
    keys.answer = appleJwks;
    now = now.add(const Duration(minutes: 2));
    expect((await cache.keysFor('ec-1')).single.kid, 'ec-1');
    expect(keys.fetches, 2);
  });

  test('but not more often than the gap: a stream of made-up key ids is not '
      'a stream of requests to the provider', () async {
    final keys = FakeKeySet(googleJwks);
    final cache = cacheOf(keys);
    for (var i = 0; i < 20; i++) {
      expect(await cache.keysFor('made-up-$i'), isEmpty);
      now = now.add(const Duration(seconds: 2));
    }
    expect(keys.fetches, 1);
  });

  test('a burst of sign-ins after a rotation asks the provider once', () async {
    final keys = FakeKeySet(appleJwks);
    final cache = cacheOf(keys);
    await Future.wait([for (var i = 0; i < 10; i++) cache.keysFor('ec-1')]);
    expect(keys.fetches, 1);
  });

  test('an unreachable provider with nothing held is told apart from a '
      'refused token', () async {
    final keys = FakeKeySet(appleJwks)..failWith = 'no route to host';
    await expectLater(
      cacheOf(keys).keysFor('ec-1'),
      throwsA(
        isA<DwJwksUnavailable>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('auth/keys'), contains('no route to host')),
        ),
      ),
    );
  });

  test('an unreachable provider does not throw away the keys it has, and is '
      'tried again after the gap', () async {
    final keys = FakeKeySet(appleJwks, maxAge: const Duration(minutes: 10));
    final cache = cacheOf(keys);
    await cache.keysFor('ec-1');
    keys.failWith = 'no route to host';
    now = now.add(const Duration(hours: 5));
    expect((await cache.keysFor('ec-1')).single.kid, 'ec-1');
    expect(keys.fetches, 2);

    keys.failWith = null;
    now = now.add(const Duration(minutes: 2));
    expect((await cache.keysFor('ec-1')).single.kid, 'ec-1');
    expect(keys.fetches, 3, reason: 'the provider is tried again, not pinned');
  });

  test('an answer with no key it can verify with keeps the held set', () async {
    final keys = FakeKeySet(appleJwks);
    final cache = cacheOf(keys);
    await cache.keysFor('ec-1');
    keys.answer = const {'keys': []};
    now = now.add(const Duration(hours: 5));
    expect((await cache.keysFor('ec-1')).single.kid, 'ec-1');
  });

  test('an answer with no key it can verify with and nothing held is a '
      'provider that cannot be used', () async {
    await expectLater(
      cacheOf(FakeKeySet(const {'keys': []})).keysFor('ec-1'),
      throwsA(isA<DwJwksUnavailable>()),
    );
  });
}
