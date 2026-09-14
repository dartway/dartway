import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_orm/dartway_orm.dart';

/// The migration namespace of the framework's own tables.
const String dwFrameworkNamespace = 'dw';

/// The framework's own tables, applied under the namespace `dw` before the
/// project's migrations.
///
/// Append-only: an applied migration is never edited (its checksum is in every
/// database that ran it); a change is a new migration in this list.
final List<DwDatabaseMigration> dwFrameworkMigrations = List.unmodifiable([
  const _DwSqlMigration('20260913_000000_dw_initial', _initialUp, _initialDown),
  const _DwSqlMigration(
    '20260914_000000_dw_stored_file',
    _storedFileUp,
    _storedFileDown,
  ),
  const _DwSqlMigration(
    '20260914_180000_dw_stored_file_bucket',
    _storedFileBucketUp,
    _storedFileBucketDown,
  ),
]);

/// A framework migration written as SQL statements. Its checksum is the hash
/// of those statements, so editing an applied one is caught by the ledger.
final class _DwSqlMigration extends DwDatabaseMigration {
  const _DwSqlMigration(this.id, this._up, this._down);

  @override
  final String id;
  final List<String> _up;
  final List<String> _down;

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
  // Accounts are what the framework knows of people; the project's profile
  // references `dw_account.id`.
  '''
CREATE TABLE dw_account (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now()
)''',
  '''
CREATE TABLE dw_identity (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE,
  kind text NOT NULL,
  value text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dw_identity_kind_value UNIQUE (kind, value)
)''',
  'CREATE INDEX dw_identity_account ON dw_identity (account_id)',
  // Tokens are stored as their SHA-256: a leaked table signs nobody in.
  '''
CREATE TABLE dw_auth_key (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE,
  token_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CONSTRAINT dw_auth_key_token_hash UNIQUE (token_hash)
)''',
  'CREATE INDEX dw_auth_key_account ON dw_auth_key (account_id)',
  // One row per code sent; the code itself only as SHA-256 over the ticket id
  // and the code. The rate limit counts rows per identifier in a window.
  '''
CREATE TABLE dw_code_ticket (
  id text PRIMARY KEY,
  kind text NOT NULL,
  identifier text NOT NULL,
  code_hash bytea NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz
)''',
  'CREATE INDEX dw_code_ticket_identifier '
      'ON dw_code_ticket (kind, identifier, created_at)',
  // Idempotency: one outcome per key within an account (NULL = anonymous, and
  // NULLs compare equal here). `result` holds the wire value of an ok outcome
  // or the refusal of a refused one.
  '''
CREATE TABLE dw_command_outcome (
  key text NOT NULL,
  account_id bigint,
  type text NOT NULL,
  status text NOT NULL CHECK (status IN ('ok', 'refused')),
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dw_command_outcome_key UNIQUE NULLS NOT DISTINCT (key, account_id)
)''',
  'CREATE INDEX dw_command_outcome_created ON dw_command_outcome (created_at)',
  // A pending job is a row; a done job is deleted. `failed_at` marks a job out
  // of attempts, kept for the operator.
  '''
CREATE TABLE dw_job (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  payload jsonb NOT NULL,
  key text,
  run_at timestamptz NOT NULL DEFAULT now(),
  attempts integer NOT NULL DEFAULT 0,
  locked_until timestamptz,
  last_error text,
  failed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
)''',
  'CREATE INDEX dw_job_due ON dw_job (run_at) WHERE failed_at IS NULL',
  // A dedup key binds only pending jobs: a job that ran out of attempts must
  // not block the next enqueue with the same key.
  'CREATE UNIQUE INDEX dw_job_key ON dw_job (key) WHERE failed_at IS NULL',
  '''
CREATE TABLE dw_recurring_job (
  name text PRIMARY KEY,
  every_micros bigint NOT NULL,
  next_run_at timestamptz NOT NULL,
  last_run_at timestamptz,
  last_error text
)''',
];

// Uploaded files. A row exists from the moment an upload is started; it is
// confirmed once the server has seen the object, and an unconfirmed one past
// its ticket and grace is removed with its object by `dw.files.cleanup`.
const List<String> _storedFileUp = [
  // The account is not deleted from under its files (no cascade): deleting
  // rows here would orphan their objects in storage, where nothing could
  // find them again. An account's files are deleted through ctx.files first.
  '''
CREATE TABLE dw_stored_file (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES dw_account (id),
  purpose text NOT NULL,
  object_key text NOT NULL,
  visibility text NOT NULL CHECK (visibility IN ('public', 'private')),
  file_name text NOT NULL,
  content_type text NOT NULL,
  byte_size bigint NOT NULL CHECK (byte_size > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  confirmed_at timestamptz,
  CONSTRAINT dw_stored_file_object_key UNIQUE (object_key)
)''',
  // Cleanup reads unconfirmed rows by age.
  'CREATE INDEX dw_stored_file_cleanup '
      'ON dw_stored_file (confirmed_at, created_at)',
  // The per-account limit of pending uploads counts only unconfirmed rows.
  'CREATE INDEX dw_stored_file_pending ON dw_stored_file (account_id, created_at) '
      'WHERE confirmed_at IS NULL',
];

const List<String> _storedFileDown = ['DROP TABLE dw_stored_file'];

// Public and private files live in two buckets, so a row names its bucket: a
// file stays where it was uploaded when the configuration names other buckets
// later, and its object is found — and deleted — there. No default: which
// bucket an existing row is in is not something a migration can know.
const List<String> _storedFileBucketUp = [
  'ALTER TABLE dw_stored_file ADD COLUMN bucket text NOT NULL',
  'ALTER TABLE dw_stored_file DROP CONSTRAINT dw_stored_file_object_key',
  'ALTER TABLE dw_stored_file ADD CONSTRAINT dw_stored_file_object '
      'UNIQUE (bucket, object_key)',
];

const List<String> _storedFileBucketDown = [
  'ALTER TABLE dw_stored_file DROP CONSTRAINT dw_stored_file_object',
  'ALTER TABLE dw_stored_file ADD CONSTRAINT dw_stored_file_object_key '
      'UNIQUE (object_key)',
  'ALTER TABLE dw_stored_file DROP COLUMN bucket',
];

const List<String> _initialDown = [
  'DROP TABLE dw_recurring_job',
  'DROP TABLE dw_job',
  'DROP TABLE dw_command_outcome',
  'DROP TABLE dw_code_ticket',
  'DROP TABLE dw_auth_key',
  'DROP TABLE dw_identity',
  'DROP TABLE dw_account',
];
