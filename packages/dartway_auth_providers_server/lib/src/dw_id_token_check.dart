import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'dw_jwt_keys.dart';
import 'dw_sign_in_providers.dart';

/// The keys a verified token's claims reach the project's hook under, in
/// `DwAuthConfig.onExternalAccountCreated`'s registration map.
///
/// They are the server's words, not the app's: whatever the app sent under a
/// `dw.` key is dropped before these are put in. An e-mail here was in a
/// token the provider signed.
abstract final class DwProviderClaim {
  /// The prefix the server reserves in the registration map.
  static const String prefix = 'dw.';

  /// The e-mail the provider gave, if any. Apple's may be its relay address
  /// (`…@privaterelay.appleid.com`) when the person chose to hide theirs.
  static const String email = 'dw.email';

  /// `'true'` when the provider says it verified that e-mail.
  static const String emailVerified = 'dw.emailVerified';

  /// Google only, and only when the person's profile carries them.
  static const String name = 'dw.name';
  static const String givenName = 'dw.givenName';
  static const String familyName = 'dw.familyName';
  static const String picture = 'dw.picture';

  /// Apple only: `'true'` when Apple believes the account is a real person's.
  static const String realUser = 'dw.realUser';
}

/// What the check made of a token.
@internal
sealed class DwTokenVerdict {
  const DwTokenVerdict();
}

/// The token is the provider's, issued for this app, and names [subject].
@internal
final class DwTokenAccepted extends DwTokenVerdict {
  const DwTokenAccepted(this.subject, this.claims, this.clientId);

  /// The provider's stable id of the person — what the identity is stored as.
  final String subject;

  /// Which of the app's client ids the token was issued for. Apple's token
  /// endpoints want the same one, and the client secret is signed for it.
  final String clientId;

  /// The claims worth handing the project, under [DwProviderClaim] keys.
  final Map<String, String> claims;
}

/// The token is not accepted, and [reason] says why — for the server's log.
/// The app is told only that the credential was rejected: which check failed
/// is a hint to whoever is trying tokens.
@internal
final class DwTokenRejected extends DwTokenVerdict {
  const DwTokenRejected(this.reason);

  final String reason;
}

/// Reads an ID token and decides whether it signs someone in.
///
/// In order: the token is three base64url parts; its header names an
/// algorithm this provider signs with; a published key of that id verifies
/// the signature; the claims say the provider issued it, for one of this
/// app's client ids, not expired; and the nonce is the one the app used.
/// Everything is checked — a token is not half accepted.
@internal
final class DwIdTokenCheck {
  const DwIdTokenCheck(this.setup, {required this.now});

  final DwSignInProvider setup;
  final DateTime now;

  /// Throws [DwJwksUnavailable] when the provider's keys cannot be learnt.
  Future<DwTokenVerdict> run(String token, {String? nonce}) async {
    final parts = token.split('.');
    if (parts.length != 3) {
      return const DwTokenRejected('the token is not three parts');
    }
    final Map<String, Object?> header;
    final Map<String, Object?> claims;
    try {
      header = _json(parts[0]);
      claims = _json(parts[1]);
    } on FormatException catch (error) {
      return DwTokenRejected('the token does not read as JSON: ${error.message}');
    }
    final algorithm = header['alg'];
    if (algorithm is! String) {
      return const DwTokenRejected('the header names no algorithm');
    }
    final kid = header['kid'] is String ? header['kid']! as String : '';

    final Uint8List signature;
    try {
      signature = DwJwtKey.decodeBase64Url(parts[2]);
    } on FormatException {
      return const DwTokenRejected('the signature is not base64url');
    }
    final signed = Uint8List.fromList(
      ascii.encode('${parts[0]}.${parts[1]}'),
    );
    final keys = await setup.keys.keysFor(kid);
    final verifying = [
      for (final key in keys)
        // The key's own algorithm decides, never the token's header: `alg`
        // is written by whoever wrote the token.
        if (key.alg == algorithm) key,
    ];
    if (verifying.isEmpty) {
      return DwTokenRejected(
        'no $algorithm key "$kid" among the ${keys.length} the provider '
        'publishes',
      );
    }
    if (!verifying.any((key) => key.verifies(signed, signature))) {
      return const DwTokenRejected('the signature is not the provider\'s');
    }

    if (claims['iss'] is! String || !setup.issuers.contains(claims['iss'])) {
      return DwTokenRejected('issued by "${claims['iss']}", not the provider');
    }
    final audience = switch (claims['aud']) {
      final String one => [one],
      final List many => many.whereType<String>().toList(),
      _ => const <String>[],
    };
    final forThisApp = audience.where(setup.clientIds.contains).toList();
    if (forThisApp.isEmpty) {
      return DwTokenRejected(
        'issued for $audience, none of this app\'s client ids',
      );
    }
    final expiry = _time(claims['exp']);
    if (expiry == null) return const DwTokenRejected('the token has no expiry');
    if (!now.isBefore(expiry.add(setup.clockSkew))) {
      return DwTokenRejected('expired at $expiry');
    }
    if (_time(claims['iat']) case final issuedAt?
        when issuedAt.subtract(setup.clockSkew).isAfter(now)) {
      return DwTokenRejected('issued at $issuedAt, which is ahead of us');
    }
    if (_nonceProblem(claims['nonce'], nonce) case final problem?) {
      return DwTokenRejected(problem);
    }
    final subject = claims['sub'];
    if (subject is! String || subject.isEmpty || subject.length > 255) {
      return const DwTokenRejected('the token names no subject');
    }
    return DwTokenAccepted(subject, _claimsOf(claims), forThisApp.first);
  }

  /// Why the token's nonce does not answer the one the app used, or null.
  ///
  /// The app sends the nonce **as it made it**. Apple's flow hashes it before
  /// it reaches Apple, and the token then carries the hash, so either form
  /// answers; anything else does not. A token that carries a nonce the app
  /// did not name is a token from another sign-in.
  String? _nonceProblem(Object? inToken, String? sent) {
    if (sent == null || sent.isEmpty) {
      if (setup.requireNonce) {
        return 'the app sent no nonce, and this provider is set to require one';
      }
      return inToken == null
          ? null
          : 'the token carries a nonce the app did not name';
    }
    if (inToken is! String || inToken.isEmpty) {
      return 'the app used a nonce and the token carries none';
    }
    final hashed = sha256.convert(utf8.encode(sent)).toString();
    return inToken == sent || inToken.toLowerCase() == hashed
        ? null
        : 'the token carries another sign-in\'s nonce';
  }

  static Map<String, String> _claimsOf(Map<String, Object?> claims) => {
    for (final MapEntry(:key, :value) in const {
      'email': DwProviderClaim.email,
      'email_verified': DwProviderClaim.emailVerified,
      'name': DwProviderClaim.name,
      'given_name': DwProviderClaim.givenName,
      'family_name': DwProviderClaim.familyName,
      'picture': DwProviderClaim.picture,
    }.entries)
      value: ?_text(claims[key]),
    // Apple sends 0, 1 or 2; only 2 is "a real person, as far as Apple
    // knows", and the project should not read a number it did not ask for.
    if (claims['real_user_status'] == 2) DwProviderClaim.realUser: 'true',
  };

  /// A claim as text: providers send `email_verified` as a boolean and as a
  /// string, and both mean the same thing.
  static String? _text(Object? value) => switch (value) {
    final String text when text.isNotEmpty => text,
    final bool flag => '$flag',
    _ => null,
  };

  static DateTime? _time(Object? value) => switch (value) {
    final int seconds => DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ),
    final String text when int.tryParse(text) != null => DateTime
        .fromMillisecondsSinceEpoch(int.parse(text) * 1000, isUtc: true),
    _ => null,
  };

  static Map<String, Object?> _json(String part) {
    final decoded = jsonDecode(utf8.decode(DwJwtKey.decodeBase64Url(part)));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('a token part is not an object');
    }
    return decoded;
  }
}
