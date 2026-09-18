import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Apple's own doors — `/auth/token` and `/auth/revoke` — are not opened by a
/// password but by a **client secret**: a short-lived JWT the project signs
/// with the private key it downloaded from Apple once, as a `.p8` file.
///
/// The signing half of ES256, and the only place in the framework where a
/// private key is used to sign with this curve. It is written here for the
/// reason the verifier is (D-034): the operation is a page of arithmetic, and
/// the alternative is a dependency in the path of every sign-in.
@internal
final class DwAppleClientSecret {
  DwAppleClientSecret({
    required this.teamId,
    required this.keyId,
    required String privateKeyPem,
    required this.clientId,
    this.lifetime = const Duration(minutes: 30),
  }) : _key = _EcPrivateKey.fromPem(privateKeyPem);

  /// Apple's team id (`iss`), ten characters.
  final String teamId;

  /// The id of the key the `.p8` holds, named in the token's header.
  final String keyId;

  /// The app's client id — its bundle id, or a services id for the web.
  final String clientId;

  /// How long a minted secret is good for. Apple allows up to six months;
  /// half an hour is enough for the call it is made for, and a secret that
  /// leaks is then worth almost nothing.
  final Duration lifetime;

  final _EcPrivateKey _key;

  /// A client secret for a call made at [now].
  String mint({DateTime? now, Random? random}) {
    final issued = (now ?? DateTime.now().toUtc());
    final header = _part({'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'});
    final claims = _part({
      'iss': teamId,
      'iat': issued.millisecondsSinceEpoch ~/ 1000,
      'exp': issued.add(lifetime).millisecondsSinceEpoch ~/ 1000,
      'aud': 'https://appleid.apple.com',
      'sub': clientId,
    });
    final signed = ascii.encode('$header.$claims');
    final signature = _key.sign(
      Uint8List.fromList(signed),
      random ?? Random.secure(),
    );
    return '$header.$claims.${_base64Url(signature)}';
  }

  static String _part(Map<String, Object?> json) =>
      _base64Url(Uint8List.fromList(utf8.encode(jsonEncode(json))));

  static String _base64Url(Uint8List bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}

/// A P-256 private key read from a `.p8` (PKCS #8) file, and ECDSA over it.
final class _EcPrivateKey {
  _EcPrivateKey(this.scalar);

  /// The private scalar `d`.
  final BigInt scalar;

  /// Reads the `-----BEGIN PRIVATE KEY-----` file Apple hands out once.
  ///
  /// PKCS #8: a sequence of the version, the algorithm (`id-ecPublicKey` with
  /// `prime256v1`) and an octet string holding the SEC1 key, whose first
  /// octet string is `d`.
  factory _EcPrivateKey.fromPem(String pem) {
    final match = RegExp(
      r'-----BEGIN (EC )?PRIVATE KEY-----([\s\S]*?)-----END (EC )?PRIVATE KEY-----',
    ).firstMatch(pem);
    if (match == null) {
      throw const FormatException(
        'Not a PEM private key: an Apple sign-in key is the .p8 file as '
        'downloaded, headers and all',
      );
    }
    final Uint8List der;
    try {
      der = base64Decode(match.group(2)!.replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      throw const FormatException('The PEM private key is not base64');
    }
    var reader = _DerReader(der).sequence();
    if (match.group(1) == null) {
      reader.skip(); // version
      final algorithm = reader.sequence();
      final family = algorithm.objectId();
      if (!_sameBytes(family, _idEcPublicKey)) {
        throw const FormatException(
          'The private key is not an elliptic curve key',
        );
      }
      final curve = algorithm.objectId();
      if (!_sameBytes(curve, _prime256v1)) {
        throw const FormatException('The private key is not on P-256');
      }
      reader = _DerReader(reader.octetString()).sequence();
    }
    reader.skip(); // version
    final scalar = _toBigInt(reader.octetString());
    if (scalar <= BigInt.zero || scalar >= _p256Order) {
      throw const FormatException('The private key is not a P-256 scalar');
    }
    return _EcPrivateKey(scalar);
  }

  static final BigInt _p256Order = BigInt.parse(
    'ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551',
    radix: 16,
  );

  /// `1.2.840.10045.2.1` and `1.2.840.10045.3.1.7`.
  static const List<int> _idEcPublicKey = [
    0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, //
  ];
  static const List<int> _prime256v1 = [
    0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, //
  ];

  /// The ECDSA signature of [message] as JWS carries it: `r` and `s`, 32
  /// bytes each.
  ///
  /// `k` is fresh randomness for every signature, and never reused: two
  /// signatures made with one `k` give the private key away to anyone holding
  /// both. A `k` that lands outside the group, or an `r` or `s` of zero, is
  /// drawn again rather than patched.
  Uint8List sign(Uint8List message, Random random) {
    final z = _toBigInt(Uint8List.fromList(sha256.convert(message).bytes))
        .remainder(_p256Order);
    for (var attempt = 0; attempt < 8; attempt++) {
      final k = _randomScalar(random);
      final point = _p256Multiply(_p256Generator, k);
      if (point == null) continue;
      final r = point.x.remainder(_p256Order);
      if (r == BigInt.zero) continue;
      final s = ((z + r * scalar) * k.modInverse(_p256Order)).remainder(
        _p256Order,
      );
      if (s == BigInt.zero) continue;
      return Uint8List.fromList([..._toBytes(r, 32), ..._toBytes(s, 32)]);
    }
    throw StateError('no signature after eight draws: the randomness is not');
  }

  static BigInt _randomScalar(Random random) {
    while (true) {
      final bytes = Uint8List.fromList([
        for (var i = 0; i < 32; i++) random.nextInt(256),
      ]);
      final value = _toBigInt(bytes);
      if (value > BigInt.zero && value < _p256Order) return value;
    }
  }
}

/// The curve arithmetic the signature needs — the same curve the verifier
/// walks, from the other side.
typedef _Point = ({BigInt x, BigInt y})?;

final BigInt _p256Prime = BigInt.parse(
  'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
  radix: 16,
);
final ({BigInt x, BigInt y}) _p256Generator = (
  x: BigInt.parse(
    '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296',
    radix: 16,
  ),
  y: BigInt.parse(
    '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
    radix: 16,
  ),
);
final BigInt _three = BigInt.from(3);

BigInt _mod(BigInt value) {
  final rest = value.remainder(_p256Prime);
  return rest.isNegative ? rest + _p256Prime : rest;
}

_Point _p256Add(_Point first, _Point second) {
  if (first == null) return second;
  if (second == null) return first;
  if (first.x == second.x) {
    if (_mod(first.y + second.y) == BigInt.zero) return null;
    if (first.y == BigInt.zero) return null;
    final slope = _mod(
      (_three * first.x * first.x - _three) *
          _mod(first.y * BigInt.two).modInverse(_p256Prime),
    );
    return _p256Line(first, first, slope);
  }
  final slope = _mod(
    (second.y - first.y) * _mod(second.x - first.x).modInverse(_p256Prime),
  );
  return _p256Line(first, second, slope);
}

_Point _p256Line(
  ({BigInt x, BigInt y}) first,
  ({BigInt x, BigInt y}) second,
  BigInt slope,
) {
  final x = _mod(slope * slope - first.x - second.x);
  return (x: x, y: _mod(slope * (first.x - x) - first.y));
}

_Point _p256Multiply(_Point point, BigInt times) {
  _Point result;
  var added = point;
  var left = times;
  while (left > BigInt.zero) {
    if (left.isOdd) result = _p256Add(result, added);
    added = _p256Add(added, added);
    left >>= 1;
  }
  return result;
}

bool _sameBytes(List<int> first, List<int> second) =>
    first.length == second.length &&
    !Iterable.generate(
      first.length,
    ).any((index) => first[index] != second[index]);

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

/// As much DER as a `.p8` file needs: sequences, object ids, octet strings.
final class _DerReader {
  _DerReader(this._bytes);

  final Uint8List _bytes;
  int _at = 0;

  _DerReader sequence() => _DerReader(_read(0x30));

  Uint8List octetString() => _read(0x04);

  List<int> objectId() => _read(0x06);

  /// Steps over the next element, whatever it is.
  void skip() {
    _at++;
    // Read the length first: `_at += _length()` takes the left side before
    // the call that moves it, and lands two bytes short.
    final length = _length();
    _at += length;
  }

  Uint8List _read(int tag) {
    if (_at >= _bytes.length || _bytes[_at] != tag) {
      throw FormatException('DER: expected tag $tag at $_at');
    }
    _at++;
    final length = _length();
    final value = Uint8List.sublistView(_bytes, _at, _at + length);
    _at += length;
    return value;
  }

  int _length() {
    var length = _bytes[_at++];
    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _bytes[_at++];
      }
    }
    return length;
  }
}
