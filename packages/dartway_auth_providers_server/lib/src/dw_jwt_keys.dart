import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// One signing key as a provider publishes it in its JWKS, and the check of a
/// signature made with it.
///
/// Verification only ever touches public numbers, so it is written here rather
/// than taken from a dependency — as the FCM assertion's RS256 signer is
/// (D-034). Both halves are small and both are covered by tokens signed with
/// `openssl` in the tests.
@internal
sealed class DwJwtKey {
  const DwJwtKey(this.kid);

  /// The key id the token's header names, or an empty string for a key set
  /// that publishes none.
  final String kid;

  /// The JWS algorithm this key verifies: `RS256`, `ES256`.
  String get alg;

  /// Whether [signature] is this key's signature of [signed] — the token's
  /// `header.payload` bytes.
  bool verifies(Uint8List signed, Uint8List signature);

  /// The keys of a JWKS document, skipping the ones this code cannot check
  /// (another algorithm, a malformed member): a provider may publish keys for
  /// more than one purpose, and a set with one unreadable member is not a
  /// reason to refuse every sign-in.
  static List<DwJwtKey> parseSet(Object? document) {
    if (document is! Map<String, Object?>) return const [];
    final keys = document['keys'];
    if (keys is! List) return const [];
    return [
      for (final key in keys)
        if (key is Map<String, Object?>) ?parse(key),
    ];
  }

  /// One JWK, or null when it is not a key this code verifies with.
  static DwJwtKey? parse(Map<String, Object?> jwk) {
    final use = jwk['use'];
    if (use != null && use != 'sig') return null;
    final kid = jwk['kid'] is String ? jwk['kid']! as String : '';
    try {
      return switch ((jwk['kty'], jwk['alg'])) {
        ('RSA', 'RS256' || null) => DwRsaJwtKey(
          kid,
          modulus: _number(jwk['n']),
          exponent: _number(jwk['e']),
        ),
        ('EC', 'ES256' || null) when jwk['crv'] == 'P-256' => DwEcJwtKey(
          kid,
          x: _number(jwk['x']),
          y: _number(jwk['y']),
        ),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// A base64url JWK member as the number it encodes.
  static BigInt _number(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('a JWK member is not base64url');
    }
    return _toBigInt(decodeBase64Url(value));
  }

  /// Base64url without padding, as every part of a JWT is encoded.
  static Uint8List decodeBase64Url(String value) =>
      base64Url.decode(value.padRight((value.length + 3) & ~3, '='));
}

/// An RSA key: RS256 is `RSASSA-PKCS1-v1_5` over SHA-256.
@internal
final class DwRsaJwtKey extends DwJwtKey {
  DwRsaJwtKey(super.kid, {required this.modulus, required this.exponent});

  final BigInt modulus;
  final BigInt exponent;

  @override
  String get alg => 'RS256';

  @override
  bool verifies(Uint8List signed, Uint8List signature) {
    final length = (modulus.bitLength + 7) >> 3;
    if (signature.length != length || modulus.bitLength < 2048) return false;
    final value = _toBigInt(signature);
    if (value >= modulus) return false;
    final encoded = _toBytes(value.modPow(exponent, modulus), length);
    // EMSA-PKCS1-v1_5: 0x00 0x01, 0xff padding, 0x00, the SHA-256
    // DigestInfo, the digest. Comparing the whole block is the check: a
    // forgery has to reproduce every byte of it.
    final expected = <int>[
      0x00,
      0x01,
      ...List.filled(length - _sha256DigestInfo.length - 35, 0xff),
      0x00,
      ..._sha256DigestInfo,
      ...sha256.convert(signed).bytes,
    ];
    if (expected.length != length) return false;
    var same = 0;
    for (var i = 0; i < length; i++) {
      same |= encoded[i] ^ expected[i];
    }
    return same == 0;
  }

  /// DER of `AlgorithmIdentifier sha256, NULL` and the digest's header.
  static const List<int> _sha256DigestInfo = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, //
    0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ];
}

/// An elliptic curve key on P-256: ES256 is ECDSA over SHA-256, and the
/// signature is `r` and `s`, 32 bytes each.
@internal
final class DwEcJwtKey extends DwJwtKey {
  DwEcJwtKey(super.kid, {required this.x, required this.y});

  final BigInt x;
  final BigInt y;

  @override
  String get alg => 'ES256';

  @override
  bool verifies(Uint8List signed, Uint8List signature) {
    if (signature.length != 64) return false;
    if (!_P256.isOnCurve(x, y)) return false;
    final r = _toBigInt(Uint8List.sublistView(signature, 0, 32));
    final s = _toBigInt(Uint8List.sublistView(signature, 32));
    if (r < BigInt.one || r >= _P256.n || s < BigInt.one || s >= _P256.n) {
      return false;
    }
    final z = _toBigInt(
      Uint8List.fromList(sha256.convert(signed).bytes),
    ).remainder(_P256.n);
    final w = s.modInverse(_P256.n);
    final point = _P256.add(
      _P256.multiply(_P256.g, (z * w).remainder(_P256.n)),
      _P256.multiply((x: x, y: y), (r * w).remainder(_P256.n)),
    );
    return point != null && point.x.remainder(_P256.n) == r;
  }
}

/// A point of P-256, or `null` for the point at infinity.
typedef _Point = ({BigInt x, BigInt y})?;

/// The NIST P-256 curve: `y² = x³ - 3x + b` over the prime field `p`, with
/// the group order `n` and the base point `g`. Only public values travel
/// through it, so the arithmetic is plain and not constant-time.
abstract final class _P256 {
  static final BigInt p = BigInt.parse(
    'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
    radix: 16,
  );
  static final BigInt n = BigInt.parse(
    'ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551',
    radix: 16,
  );
  static final BigInt b = BigInt.parse(
    '5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b',
    radix: 16,
  );
  static final ({BigInt x, BigInt y}) g = (
    x: BigInt.parse(
      '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296',
      radix: 16,
    ),
    y: BigInt.parse(
      '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
      radix: 16,
    ),
  );

  static final BigInt _three = BigInt.from(3);

  /// Whether `(x, y)` is a point of the curve — a key that is not is not a
  /// key, and verifying against one proves nothing.
  static bool isOnCurve(BigInt x, BigInt y) {
    if (x < BigInt.zero || x >= p || y < BigInt.zero || y >= p) return false;
    return y.modPow(BigInt.two, p) ==
        _mod(x.modPow(_three, p) - _three * x + b);
  }

  static _Point add(_Point first, _Point second) {
    if (first == null) return second;
    if (second == null) return first;
    if (first.x == second.x) {
      return _mod(first.y + second.y) == BigInt.zero ? null : _double(first);
    }
    return _lineThrough(
      first,
      second,
      _mod((second.y - first.y) * _inverse(second.x - first.x)),
    );
  }

  static _Point _double(({BigInt x, BigInt y}) point) {
    if (point.y == BigInt.zero) return null;
    // The curve's `a` is -3, so the tangent's slope is (3x² - 3) / 2y.
    return _lineThrough(
      point,
      point,
      _mod(
        (_three * point.x * point.x - _three) *
            _inverse(point.y * BigInt.two),
      ),
    );
  }

  /// The third point of the curve on the line of [slope] through [first] and
  /// [second], mirrored — the sum of the two.
  static _Point _lineThrough(
    ({BigInt x, BigInt y}) first,
    ({BigInt x, BigInt y}) second,
    BigInt slope,
  ) {
    final x = _mod(slope * slope - first.x - second.x);
    return (x: x, y: _mod(slope * (first.x - x) - first.y));
  }

  /// The representative of [value] in `0 <= r < p`; `remainder` alone keeps
  /// the sign of a negative intermediate.
  static BigInt _mod(BigInt value) {
    final rest = value.remainder(p);
    return rest.isNegative ? rest + p : rest;
  }

  static _Point multiply(_Point point, BigInt times) {
    _Point result;
    var added = point;
    var left = times;
    while (left > BigInt.zero) {
      if (left.isOdd) result = add(result, added);
      added = add(added, added);
      left >>= 1;
    }
    return result;
  }

  static BigInt _inverse(BigInt value) => _mod(value).modInverse(p);
}

BigInt _toBigInt(Uint8List bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List _toBytes(BigInt value, int length) {
  final bytes = Uint8List(length);
  var left = value;
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (left & BigInt.from(0xff)).toInt();
    left >>= 8;
  }
  return bytes;
}
