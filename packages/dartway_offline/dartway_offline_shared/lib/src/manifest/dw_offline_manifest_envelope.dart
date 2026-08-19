import 'dart:convert';
import 'dart:typed_data';

/// The wire contract of a signed offline package manifest.
///
/// Both halves of the offline family read this file rather than restating it:
/// `dartway_offline_server` signs the bytes it produces, `dartway_offline_flutter`
/// verifies them. A signing frame that drifts between the two does not fail to
/// compile — it fails as an unverifiable manifest on a stranger's device, so the
/// frame lives in one place by construction.
abstract final class DwOfflineManifestEnvelope {
  /// The version of the envelope layout, covered by the signature itself.
  static const int schemaVersion = 2;

  /// The only signature algorithm this schema version accepts.
  static const String algorithmName = 'Ed25519';

  /// The domain separator that keeps these signatures from being replayed
  /// against any other Ed25519 context.
  static const String domainSeparator = 'dartway.offline.manifest\u0000';

  /// The exact keys an envelope carries — no more, no fewer.
  static const Set<String> envelopeFields = {
    'algorithm',
    'keyId',
    'payload',
    'schemaVersion',
    'signature',
  };

  /// The bytes an [algorithm]/[keyId]/[payloadBytes] triple is signed over.
  ///
  /// Every variable-length field is length-prefixed so that no rearrangement of
  /// field contents can produce the same byte string.
  static List<int> signingBytes({
    required int schemaVersion,
    required String algorithm,
    required String keyId,
    required List<int> payloadBytes,
  }) {
    final signingBuffer = BytesBuilder(copy: false)
      ..add(ascii.encode(domainSeparator))
      ..add(unsigned32(schemaVersion))
      ..add(lengthPrefixed(utf8.encode(algorithm)))
      ..add(lengthPrefixed(utf8.encode(keyId)))
      ..add(lengthPrefixed(payloadBytes));
    return signingBuffer.takeBytes();
  }

  /// [bytes] preceded by its own length as a big-endian unsigned 32-bit value.
  static List<int> lengthPrefixed(List<int> bytes) => [
    ...unsigned32(bytes.length),
    ...bytes,
  ];

  /// [integer] as four big-endian bytes.
  static List<int> unsigned32(int integer) => [
    (integer >> 24) & 0xff,
    (integer >> 16) & 0xff,
    (integer >> 8) & 0xff,
    integer & 0xff,
  ];

  /// Base64url without padding, the encoding the envelope uses for bytes.
  static String encodeUnpadded(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
