import 'package:dartway_auth_providers_server/dartway_auth_providers_server.dart';
import 'package:dartway_auth_providers_server/src/dw_id_token_check.dart';
import 'package:test/test.dart';

import 'fixtures/provider_tokens.dart';
import 'support/fake_key_set.dart';

/// What a token has to be to sign someone in, one requirement at a time —
/// each of them is the whole door.
void main() {
  // Between the fixtures' `iat` (2030) and their `exp` (2033).
  final signingTime = DateTime.utc(2031, 5, 1);

  DwAppleSignIn apple({
    List<String> clientIds = const ['com.club.app'],
    bool requireNonce = true,
    FakeKeySet? keys,
  }) => DwAppleSignIn(
    clientIds: clientIds,
    requireNonce: requireNonce,
    fetchKeys: (keys ?? FakeKeySet(appleJwks)).fetch,
  );

  DwGoogleSignIn google({
    List<String> clientIds = const ['1-android.apps.googleusercontent.com'],
  }) => DwGoogleSignIn(
    clientIds: clientIds,
    fetchKeys: FakeKeySet(googleJwks).fetch,
  );

  Future<DwTokenVerdict> check(
    DwSignInProvider setup,
    String token, {
    String? nonce,
    DateTime? at,
  }) => DwIdTokenCheck(setup, now: at ?? signingTime).run(token, nonce: nonce);

  String rejection(DwTokenVerdict verdict) =>
      (verdict as DwTokenRejected).reason;

  /// One token's claims under another's signature.
  String forged(String claimsOf, String signatureOf) {
    final parts = claimsOf.split('.');
    return '${parts[0]}.${parts[1]}.${signatureOf.split('.').last}';
  }

  group('an accepted token', () {
    test('signs in the subject the provider named, with its claims', () async {
      expect(
        await check(apple(), appleToken, nonce: 'deadbeef'),
        isA<DwTokenAccepted>()
            .having((a) => a.subject, 'subject', '000123.abc')
            .having((a) => a.claims, 'claims', {
              DwProviderClaim.email: 'ada@example.com',
              DwProviderClaim.emailVerified: 'true',
            }),
      );
    });

    test("carries Google's name and picture, and its boolean e-mail flag",
        () async {
      final verdict = await check(google(), googleToken);
      expect((verdict as DwTokenAccepted).subject, '11223344');
      expect(verdict.claims, {
        DwProviderClaim.email: 'ada@example.com',
        DwProviderClaim.emailVerified: 'true',
        DwProviderClaim.name: 'Ada Lovelace',
        DwProviderClaim.givenName: 'Ada',
        DwProviderClaim.familyName: 'Lovelace',
        DwProviderClaim.picture: 'https://example.com/a.png',
      });
    });

    test("is any of the app's client ids, not only the first — Android, iOS "
        'and the web have their own', () async {
      expect(
        await check(
          apple(clientIds: ['com.club.app.web', 'com.club.app']),
          appleToken,
          nonce: 'deadbeef',
        ),
        isA<DwTokenAccepted>(),
      );
      expect(
        await check(apple(), appleTokenForSeveralApps, nonce: 'deadbeef'),
        isA<DwTokenAccepted>(),
        reason: 'an `aud` list holding this app is this app',
      );
    });
  });

  group('a token is refused when', () {
    test('it is not a token at all', () async {
      for (final token in ['', 'one.two', 'a.b.c.d', 'not!base64.x.y']) {
        expect(
          await check(apple(), token, nonce: 'deadbeef'),
          isA<DwTokenRejected>(),
          reason: 'token "$token"',
        );
      }
    });

    test("the signature is another token's", () async {
      expect(
        rejection(
          await check(
            apple(),
            forged(appleToken, appleTokenOtherSubject),
            nonce: 'deadbeef',
          ),
        ),
        contains('not the provider'),
      );
    });

    test('it carries no signature and says `alg: none` — the oldest forgery '
        'there is', () async {
      expect(
        rejection(await check(apple(), appleTokenUnsigned, nonce: 'deadbeef')),
        contains('no none key'),
      );
    });

    test('the provider publishes no key of that id', () async {
      final keys = FakeKeySet(googleJwks);
      expect(
        rejection(
          await check(apple(keys: keys), appleToken, nonce: 'deadbeef'),
        ),
        contains('no ES256 key "ec-1"'),
      );
    });

    test('someone else issued it', () async {
      expect(
        rejection(
          await check(apple(), appleTokenFromElsewhere, nonce: 'deadbeef'),
        ),
        contains('not the provider'),
      );
    });

    test('it was issued for another app', () async {
      expect(
        rejection(
          await check(apple(), appleTokenForAnotherApp, nonce: 'deadbeef'),
        ),
        contains('none of this app'),
      );
      expect(
        rejection(
          await check(
            apple(clientIds: ['com.other.app']),
            appleToken,
            nonce: 'deadbeef',
          ),
        ),
        contains('none of this app'),
      );
    });

    test('it has expired — though not while it is only clock skew away',
        () async {
      // The fixture's `exp`, 2033-05-18T03:33:20Z.
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        2000000000 * 1000,
        isUtc: true,
      );
      expect(
        await check(
          apple(),
          appleToken,
          nonce: 'deadbeef',
          at: expiry.add(const Duration(minutes: 1)),
        ),
        isA<DwTokenAccepted>(),
        reason: 'two minutes of skew are allowed for the provider’s clock',
      );
      expect(
        rejection(
          await check(
            apple(),
            appleToken,
            nonce: 'deadbeef',
            at: expiry.add(const Duration(minutes: 5)),
          ),
        ),
        contains('expired'),
      );
      expect(
        rejection(await check(apple(), appleTokenExpired, nonce: 'deadbeef')),
        contains('expired'),
      );
    });

    test('it is dated beyond the skew into the future', () async {
      expect(
        rejection(
          await check(apple(), appleTokenFromTheFuture, nonce: 'deadbeef'),
        ),
        contains('ahead of us'),
      );
    });

    test('it names no subject', () async {
      expect(
        rejection(
          await check(apple(), appleTokenWithoutSubject, nonce: 'deadbeef'),
        ),
        contains('no subject'),
      );
    });
  });

  group('the nonce', () {
    test("answers the one the app used, hashed as Apple's flow hashes it",
        () async {
      expect(
        await check(apple(), appleTokenHashedNonce, nonce: 'a-raw-nonce'),
        isA<DwTokenAccepted>(),
      );
    });

    test("refuses another sign-in's nonce", () async {
      expect(
        rejection(await check(apple(), appleToken, nonce: 'another')),
        contains('another sign-in'),
      );
    });

    test('is required where the project requires it', () async {
      expect(
        rejection(await check(apple(), appleTokenWithoutNonce)),
        contains('sent no nonce'),
      );
    });

    test('a token carrying one the app did not name is refused, even where '
        'nonces are not required', () async {
      expect(
        rejection(await check(apple(requireNonce: false), appleToken)),
        contains('did not name'),
      );
    });

    test('a nonce the app used and the token lacks is refused', () async {
      expect(
        rejection(
          await check(
            apple(requireNonce: false),
            appleTokenWithoutNonce,
            nonce: 'used-one',
          ),
        ),
        contains('carries none'),
      );
    });
  });

  group("the provider's keys", () {
    test('are fetched once and then held', () async {
      final keys = FakeKeySet(appleJwks);
      final setup = apple(keys: keys);
      await check(setup, appleToken, nonce: 'deadbeef');
      await check(setup, appleToken, nonce: 'deadbeef');
      expect(keys.fetches, 1);
    });

    test('unreachable and never held, the check says so rather than refusing '
        'the token', () async {
      final keys = FakeKeySet(appleJwks)..failWith = 'no route to host';
      await expectLater(
        check(apple(keys: keys), appleToken, nonce: 'deadbeef'),
        throwsA(isA<DwJwksUnavailable>()),
      );
    });

    test('unreachable while a set is held, the held one keeps signing people '
        'in', () async {
      final keys = FakeKeySet(appleJwks);
      final setup = apple(keys: keys);
      expect(
        await check(setup, appleToken, nonce: 'deadbeef'),
        isA<DwTokenAccepted>(),
      );
      keys.failWith = 'no route to host';
      expect(
        await check(setup, appleToken, nonce: 'deadbeef'),
        isA<DwTokenAccepted>(),
      );
    });
  });
}
