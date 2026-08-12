import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// The public half of the key pair DartWay Studio signs bridge access tokens
/// with: base64 of the 32 raw Ed25519 public-key bytes.
///
/// It ships inside this package deliberately. A public key only *checks*
/// signatures — it cannot make them — so it is harmless in the open, and it is
/// the same for every project, which is the whole point: a team connecting its
/// app to Studio has nothing to copy out of Studio, nothing to keep secret and
/// nothing to replace when the pair is rotated. They update this package.
///
/// One pair covers every Studio environment, so an app trusts one key rather
/// than a list. That is a deliberate trade: it is what keeps the app's build
/// free of per-environment configuration, and it is what will have to be
/// revisited the day Studio runs on someone else's servers.
const studioSigningPublicKey = 'gpXp+7p3BGDYFMvR2JHaBYuT1DaRsKhVeIBSgye44LM=';

/// Separates a token's payload from its signature.
const _tokenSegmentSeparator = '.';

/// Verifies an access token presented by a connecting Studio.
///
/// **The wire format** — two base64url segments, unpadded, joined by a dot:
///
/// ```text
/// <payload>.<signature>
/// payload   = base64url( utf8( {"origin":"https://app.example","exp":1765540000} ) )
/// signature = base64url( ed25519_sign( privateKey, ascii(payload) ) )
/// ```
///
/// `origin` is the address the token is good for and `exp` is its expiry in
/// whole seconds since the Unix epoch. The signature covers the payload
/// **segment as written**, not the JSON it decodes to: whoever signs and
/// whoever verifies then agree byte for byte without having to agree on how a
/// map is serialised.
///
/// Returns true only when all four hold: the token parses, its signature
/// checks out against [publicKey], its `origin` is [appOrigin], and its `exp`
/// is still ahead of [now] (the current time when omitted). Anything else —
/// a malformed token, a foreign origin, an expired one, one signed by another
/// key — is false rather than an exception: a connection is refused the same
/// way whatever is wrong with it, and the app carries on running.
///
/// Origins are compared as [Uri.origin] (scheme, host and port; case and a
/// trailing slash do not matter). An empty [appOrigin] matches nothing — an
/// app that names no address of its own is not deciding here whether to accept
/// the connection; see [studioSignedAccessValidator], which is where that
/// decision lives.
Future<bool> verifyStudioBridgeToken(
  String accessToken, {
  required String appOrigin,
  String publicKey = studioSigningPublicKey,
  DateTime? now,
}) async {
  final expectedOrigin = _normalizedOrigin(appOrigin);
  if (expectedOrigin.isEmpty) return false;

  final segments = accessToken.split(_tokenSegmentSeparator);
  if (segments.length != 2) return false;
  final payloadSegment = segments.first;

  final Map<String, dynamic> claims;
  final List<int> signature;
  final List<int> publicKeyBytes;
  try {
    claims =
        jsonDecode(utf8.decode(_decodeSegment(payloadSegment)))
            as Map<String, dynamic>;
    signature = _decodeSegment(segments.last);
    publicKeyBytes = base64.decode(publicKey);
  } catch (_) {
    return false;
  }

  if (_normalizedOrigin(claims['origin']) != expectedOrigin) return false;

  final expiresAtSeconds = claims['exp'];
  if (expiresAtSeconds is! int) return false;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(
    expiresAtSeconds * 1000,
    isUtc: true,
  );
  if (!expiresAt.isAfter((now ?? DateTime.now()).toUtc())) return false;

  return Ed25519().verify(
    ascii.encode(payloadSegment),
    signature: Signature(
      signature,
      publicKey: SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      ),
    ),
  );
}

/// The access-token check an app hands to `StudioBridgeHost.attach`: accept a
/// connecting Studio only when it presents a token issued for [appOrigin] —
/// this app's own public address — and signed by Studio's key.
///
/// A stolen token is therefore worthless anywhere but here, which is the
/// property the whole scheme exists for.
///
/// **An empty [appOrigin] accepts any connection.** That is the zero-config
/// local-dev mode: a build that was never told what address it answers at (no
/// `STUDIO_APP_ORIGIN` define) lets a Studio on the same machine drive it
/// without anyone issuing keys. A deployed build names its address and from
/// then on only a signed token gets in.
///
/// [publicKey] exists for tests and for the day an app has to trust a Studio
/// running on someone else's servers; a normal build leaves it alone.
Future<bool> Function(String accessToken) studioSignedAccessValidator(
  String appOrigin, {
  String publicKey = studioSigningPublicKey,
}) =>
    (accessToken) async =>
        appOrigin.trim().isEmpty ||
        await verifyStudioBridgeToken(
          accessToken,
          appOrigin: appOrigin,
          publicKey: publicKey,
        );

/// Decodes one unpadded base64url segment, restoring the padding `base64Url`
/// insists on.
List<int> _decodeSegment(String segment) =>
    base64Url.decode(segment.padRight((segment.length + 3) & ~3, '='));

/// Scheme, host and port of an address, so that `https://App.Example/` and
/// `https://app.example` are the same origin. Anything that is not a URL with
/// a host compares as itself.
String _normalizedOrigin(Object? address) {
  if (address is! String) return '';
  final trimmed = address.trim();
  if (trimmed.isEmpty) return '';
  try {
    return Uri.parse(trimmed).origin;
  } on FormatException {
    return trimmed;
  } on StateError {
    return trimmed;
  }
}
