import 'dart:convert';

import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

/// The command as it travels: what an app sends is what the server reads.
void main() {
  final protocol = DwWireProtocol(
    dwAuthProvidersProtocolEntries,
    include: DwWireProtocol.core,
  );

  DwSignInWithProvider readBack(DwSignInWithProvider command) {
    final json = jsonDecode(jsonEncode(command.toJson()));
    return protocol.decodeNamed(command.dwTypeName, json)
        as DwSignInWithProvider;
  }

  test('travels and comes back equal, with and without its optional parts',
      () {
    for (final command in [
      const DwSignInWithProvider(
        provider: DwAuthProvider.apple,
        idToken: 'header.payload.signature',
        nonce: 'n-1',
        registration: {'firstName': 'Ada'},
      ),
      const DwSignInWithProvider(
        provider: DwAuthProvider.google,
        idToken: 'header.payload.signature',
      ),
    ]) {
      expect(readBack(command), command);
    }
  });

  test('carries the registration it was given', () {
    final read = readBack(
      const DwSignInWithProvider(
        provider: DwAuthProvider.apple,
        idToken: 't',
        nonce: 'n',
        registration: {'firstName': 'Ada', 'marketing': 'true'},
      ),
    );
    expect(read.registration, {'firstName': 'Ada', 'marketing': 'true'});
  });

  test('leaves out what it does not carry, so a default costs no bytes', () {
    expect(
      const DwSignInWithProvider(
        provider: DwAuthProvider.google,
        idToken: 't',
      ).toJson(),
      {'provider': 'google', 'idToken': 't'},
    );
  });

  test('a provider the app does not know is the app being out of date, not a '
      'value to guess at', () {
    expect(
      () => protocol.decodeNamed('DwSignInWithProvider', const {
        'provider': 'vk',
        'idToken': 't',
      }),
      throwsA(isA<DwUnknownEnumValue>()),
    );
  });

  test('the refusal codes are the ones the server answers with', () {
    expect(
      DwProviderRefusal.values.map((r) => r.code),
      ['dw.providerCredentialRejected', 'dw.providerUnreachable'],
    );
  });

  test('is registered under its own name', () {
    expect(protocol.knows(DwSignInWithProvider), isTrue);
    expect(
      protocol.entries.map((e) => e.name),
      contains('DwSignInWithProvider'),
    );
  });
}
