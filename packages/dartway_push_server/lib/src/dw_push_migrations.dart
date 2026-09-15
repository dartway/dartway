import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

/// The migration namespace of push.
const String dwPushNamespace = 'push';

/// The push tables, applied under the namespace `push` after the
/// framework's own (devices reference accounts and session keys).
///
/// Append-only: an applied migration is never edited — its checksum is in
/// every database that ran it; a change is a new migration in this list.
final List<DwDatabaseMigration> dwPushMigrations = List.unmodifiable([
  const _PushSqlMigration(
    '20260915_000000_push_initial',
    _initialUp,
    _initialDown,
  ),
]);

final class _PushSqlMigration extends DwDatabaseMigration {
  const _PushSqlMigration(this.id, this._up, this._down);

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
  // A device is a token of one transport, owned by the account that last
  // registered it and bound to the session key it was registered with: a
  // revoked key (sign-out anywhere) stops its pushes at once, and its removal
  // removes the device. The same token string of two transports is two rows —
  // an invalid FCM token never takes a RuStore registration with it.
  '''
CREATE TABLE dw_push_device (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE,
  key_id bigint NOT NULL REFERENCES dw_auth_key (id) ON DELETE CASCADE,
  transport text NOT NULL CHECK (transport IN ('fcm', 'rustore')),
  token text NOT NULL,
  platform text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dw_push_device_token UNIQUE (transport, token)
)''',
  'CREATE INDEX dw_push_device_account '
      'ON dw_push_device (account_id, updated_at DESC, id DESC)',
  'CREATE INDEX dw_push_device_key ON dw_push_device (key_id)',
  // What one send says, stored once for all its recipients. `data` is the
  // provider data map (payload and link).
  '''
CREATE TABLE dw_push_message (
  id bigserial PRIMARY KEY,
  category text NOT NULL,
  title text NOT NULL,
  body text,
  image_url text,
  data jsonb NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)''',
  // One recipient of one message. Pending while `finished_at` is null; kept
  // after it for `retention`, which is also how long its dedup key holds.
  // `done_devices` are the devices this delivery has settled (accepted or
  // refused for good), so a retry never sends twice to one device; `sent`
  // says whether any accepted. `lease_id` names the run holding the claim.
  '''
CREATE TABLE dw_push_delivery (
  id bigserial PRIMARY KEY,
  message_id bigint NOT NULL REFERENCES dw_push_message (id) ON DELETE CASCADE,
  account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE,
  dedup_key text,
  run_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  lease_id text,
  locked_until timestamptz,
  done_devices bigint[] NOT NULL DEFAULT '{}',
  sent boolean NOT NULL DEFAULT false,
  last_error text,
  outcome text CHECK (outcome IN ('sent', 'skipped', 'noDevices', 'failed', 'expired')),
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dw_push_delivery_finished CHECK ((outcome IS NULL) = (finished_at IS NULL))
)''',
  'CREATE UNIQUE INDEX dw_push_delivery_dedup '
      'ON dw_push_delivery (account_id, dedup_key) WHERE dedup_key IS NOT NULL',
  // The claim reads pending rows by due time; finished rows are not in it.
  'CREATE INDEX dw_push_delivery_due '
      'ON dw_push_delivery (run_at, id) WHERE finished_at IS NULL',
  'CREATE INDEX dw_push_delivery_message ON dw_push_delivery (message_id)',
  'CREATE INDEX dw_push_delivery_retention '
      'ON dw_push_delivery (finished_at) WHERE finished_at IS NOT NULL',
];

const List<String> _initialDown = [
  'DROP TABLE dw_push_delivery',
  'DROP TABLE dw_push_message',
  'DROP TABLE dw_push_device',
];
