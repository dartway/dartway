import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

/// The migration namespace of analytics.
const String dwAnalyticsNamespace = 'analytics';

/// The analytics tables, applied under the namespace `analytics` after the
/// framework's own (events reference accounts).
///
/// Append-only: an applied migration is never edited; a change is a new
/// migration in this list.
final List<DwDatabaseMigration> dwAnalyticsMigrations = List.unmodifiable([
  const _AnalyticsSqlMigration(
    '20260917_000000_analytics_initial',
    _initialUp,
    _initialDown,
  ),
]);

final class _AnalyticsSqlMigration extends DwDatabaseMigration {
  const _AnalyticsSqlMigration(this.id, this._up, this._down);

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
  // One installation of the app, by the id it keeps on the device. It links
  // what a person did before signing in to the account they signed in as,
  // and carries the running session: the session a new event belongs to is
  // decided against the install's last event, under its row lock.
  // `account_id` is the last account seen; a deleted account leaves the
  // install anonymous rather than taking its history with it.
  '''
CREATE TABLE dw_analytics_install (
  install_id text PRIMARY KEY,
  platform text NOT NULL,
  app_version text NOT NULL,
  account_id bigint REFERENCES dw_account (id) ON DELETE SET NULL,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  last_event_at timestamptz,
  session_number integer NOT NULL DEFAULT 0
)''',
  'CREATE INDEX dw_analytics_install_account '
      'ON dw_analytics_install (account_id) WHERE account_id IS NOT NULL',
  'CREATE INDEX dw_analytics_install_seen ON dw_analytics_install (last_seen_at)',
  // One event. From the app it has an install, the install's running number
  // (unique: a batch sent twice is stored once) and a session; from the
  // server (`source = 'server'`) it has none of them. `occurred_at` is the
  // device's clock, `received_at` the server's.
  '''
CREATE TABLE dw_analytics_event (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  source text NOT NULL CHECK (source IN ('app', 'server')),
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  install_id text REFERENCES dw_analytics_install (install_id) ON DELETE CASCADE,
  sequence bigint,
  session_number integer,
  account_id bigint REFERENCES dw_account (id) ON DELETE SET NULL,
  platform text,
  app_version text,
  properties jsonb NOT NULL DEFAULT '{}',
  CONSTRAINT dw_analytics_event_once UNIQUE (install_id, sequence),
  CONSTRAINT dw_analytics_event_origin CHECK (
    (source = 'app') = (install_id IS NOT NULL AND sequence IS NOT NULL))
)''',
  'CREATE INDEX dw_analytics_event_name '
      'ON dw_analytics_event (name, occurred_at)',
  'CREATE INDEX dw_analytics_event_account '
      'ON dw_analytics_event (account_id, occurred_at) '
      'WHERE account_id IS NOT NULL',
  'CREATE INDEX dw_analytics_event_install '
      'ON dw_analytics_event (install_id, occurred_at)',
  'CREATE INDEX dw_analytics_event_received '
      'ON dw_analytics_event (received_at)',
];

const List<String> _initialDown = [
  'DROP TABLE dw_analytics_event',
  'DROP TABLE dw_analytics_install',
];
