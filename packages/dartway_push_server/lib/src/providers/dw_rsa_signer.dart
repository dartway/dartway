import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// RS256 (RSASSA-PKCS1-v1_5 with SHA-256) over a PEM private key — what a
/// Google service account signs its OAuth assertion with. A few dozen lines
/// of our own instead of a dependency, as SigV4 is for uploads (D-034).
@internal
final class DwRsaSigner {
  DwRsaSigner._(BigInt n, this._p, this._q, this._dP, this._dQ, this._qInv)
    : _length = (n.bitLength + 7) >> 3;

  /// Reads a `PRIVATE KEY` (PKCS #8) or `RSA PRIVATE KEY` (PKCS #1) PEM.
  /// Throws [FormatException] for anything else.
  factory DwRsaSigner.fromPem(String pem) {
    final match = RegExp(
      r'-----BEGIN (RSA )?PRIVATE KEY-----([\s\S]*?)-----END (RSA )?PRIVATE KEY-----',
    ).firstMatch(pem);
    if (match == null) {
      throw const FormatException('Not a PEM private key');
    }
    final Uint8List der;
    try {
      der = base64Decode(match.group(2)!.replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      throw const FormatException('The PEM private key is not base64');
    }
    var reader = _DerReader(der).sequence();
    if (match.group(1) == null) {
      // PKCS #8: version, algorithm, and the PKCS #1 key in an octet string.
      reader.integer();
      final algorithm = reader.sequence();
      if (!_bytesEqual(algorithm.objectId(), _rsaEncryption)) {
        throw const FormatException('The private key is not an RSA key');
      }
      reader = _DerReader(reader.octetString()).sequence();
    }
    reader.integer(); // version
    final n = reader.integer();
    reader.integer(); // public exponent
    reader.integer(); // private exponent: CRT below does not need it
    final p = reader.integer();
    final q = reader.integer();
    final dP = reader.integer();
    final dQ = reader.integer();
    final qInv = reader.integer();
    return DwRsaSigner._(n, p, q, dP, dQ, qInv);
  }

  final BigInt _p;
  final BigInt _q;
  final BigInt _dP;
  final BigInt _dQ;
  final BigInt _qInv;
  final int _length;

  /// DER of `AlgorithmIdentifier sha256, NULL` and the digest's header.
  static final List<int> _sha256DigestInfo = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, //
    0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ];

  static final List<int> _rsaEncryption = [
    0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, //
  ];

  /// The signature of [message].
  Uint8List sign(List<int> message) {
    final digest = sha256.convert(message).bytes;
    final t = [..._sha256DigestInfo, ...digest];
    // EMSA-PKCS1-v1_5: 00 01 FF…FF 00 T
    final encoded = Uint8List(_length)
      ..[1] = 0x01
      ..fillRange(2, _length - t.length - 1, 0xff)
      ..setRange(_length - t.length, _length, t);
    final m = _toBigInt(encoded);
    // Chinese remainder: two half-size exponentiations.
    final m1 = m.modPow(_dP, _p);
    final m2 = m.modPow(_dQ, _q);
    final h = (_qInv * (m1 - m2)) % _p;
    return _toBytes(m2 + h * _q, _length);
  }

  static BigInt _toBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _toBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var rest = value;
    final mask = BigInt.from(0xff);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (rest & mask).toInt();
      rest = rest >> 8;
    }
    return bytes;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Reads the DER elements a private key is made of.
final class _DerReader {
  _DerReader(this._bytes, [this._offset = 0, int? end])
    : _end = end ?? _bytes.length;

  final Uint8List _bytes;
  int _offset;
  final int _end;

  (int, int, int) _header(int expectedTag) {
    if (_offset + 2 > _end) throw const FormatException('Truncated key');
    final tag = _bytes[_offset++];
    if (tag != expectedTag) {
      throw FormatException(
        'Unexpected element 0x${tag.toRadixString(16)} in the key',
      );
    }
    var length = _bytes[_offset++];
    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      if (count > 4 || _offset + count > _end) {
        throw const FormatException('Bad length in the key');
      }
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _bytes[_offset++];
      }
    }
    final start = _offset;
    if (start + length > _end) throw const FormatException('Truncated key');
    _offset = start + length;
    return (tag, start, length);
  }

  _DerReader sequence() {
    final (_, start, length) = _header(0x30);
    return _DerReader(_bytes, start, start + length);
  }

  BigInt integer() {
    final (_, start, length) = _header(0x02);
    return DwRsaSigner._toBigInt(_bytes.sublist(start, start + length));
  }

  Uint8List octetString() {
    final (_, start, length) = _header(0x04);
    return _bytes.sublist(start, start + length);
  }

  Uint8List objectId() {
    final (_, start, length) = _header(0x06);
    final value = _bytes.sublist(start, start + length);
    // The NULL parameters that follow, when present, are not needed.
    return value;
  }
}
