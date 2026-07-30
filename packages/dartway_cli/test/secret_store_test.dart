import 'package:dartway_cli/src/deploy/secret_store.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Parses `key: <encoded>` the way Serverpod's password loader would, and
/// returns the value it ends up with.
String roundTrip(String value) {
  final document = loadYaml(
    'staging:\n  secret: ${DwSecretStore.encodeScalar(value)}\n',
  );
  return document['staging']['secret'] as String;
}

void main() {
  group('encodeScalar', () {
    // A secret that does not survive the trip to the server is worse than a
    // missing one: the server starts and fails somewhere far from here.
    const awkward = [
      'plain',
      "with'single'quotes",
      r'with"double"quotes',
      r'with\backslash',
      r'with\\double\\backslash',
      r'with$dollar and ${braces}',
      'with: colon and # hash',
      'with spaces  and\ttab',
      '-----BEGIN KEY-----abc/def+ghi=',
      "''",
      '@leading-at',
      '*leading-star',
      'true',
      '12345',
    ];

    for (final value in awkward) {
      test('round-trips ${value.length} chars: $value', () {
        expect(roundTrip(value), value);
      });
    }

    test('keeps a generated hex secret intact', () {
      const generated =
          'a3f1c2d4e5b6a7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f70';
      expect(roundTrip(generated), generated);
    });

    test('doubles the single quote rather than escaping it', () {
      expect(DwSecretStore.encodeScalar("it's"), "'it''s'");
    });
  });
}
