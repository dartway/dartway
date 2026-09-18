import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

/// The migration namespace of the sign-in providers.
const String dwAuthProvidersNamespace = 'auth_providers';

/// The one table the providers keep: the refresh token Apple hands out at the
/// first sign-in, which is the only thing that can revoke a person's tokens
/// when they delete their account.
final List<DwDatabaseMigration> dwAuthProvidersMigrations = List.unmodifiable([
  const _AuthProvidersSqlMigration(
    '20260918_000000_auth_providers_initial',
    _initialUp,
    _initialDown,
  ),
]);

final class _AuthProvidersSqlMigration extends DwDatabaseMigration {
  const _AuthProvidersSqlMigration(this.id, this._up, this._down);

  @override
  final String id;
  final List<String> _up;
  final List<String> _down;

  @override
  List<DwMigrationRef> get dependsOn => const [
    DwMigrationRef('dw', '20260913_000000_dw_initial'),
  ];

  @override
  String get checksum => sha256
      .convert(utf8.encode([..._up, '--down--', ..._down].join(';\n')))
      .toString();

  @override
  Future<void> up(DwMigrationContext m) async {
    for (final statement in _up) {
      await m.sql(statement);
    }
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    for (final statement in _down) {
      await m.sql(statement);
    }
  }
}

const List<String> _initialUp = [
  // One row per account and provider. The refresh token is a credential: no
  // handler reads this table, nothing leaves the server with it, and it is
  // kept for exactly one purpose — telling the provider, when the person
  // deletes their account, that this app is no longer theirs.
  //
  // `ON DELETE CASCADE` is the backstop, not the plan: the module reads the
  // row and hands it to the revoking job while the account is still there.
  '''
CREATE TABLE dw_provider_token (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE,
  provider text NOT NULL,
  subject text NOT NULL,
  client_id text NOT NULL,
  refresh_token text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dw_provider_token_one_per_provider UNIQUE (account_id, provider)
)''',
];

const List<String> _initialDown = ['DROP TABLE dw_provider_token'];
