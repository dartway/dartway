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
    // Its first text added the column NOT NULL outright, which fails on a
    // table with rows; wherever it applied, the table was empty and it left
    // what this text leaves (D-056).
    supersededChecksums: {
      '718954535b1d69401c8392d30a11428e46dc6a94dc6869f75aa845acd0b4b6b6',
    },
  ),
  const _DwSqlMigration(
    '20260914_220000_dw_keys_and_identities',
    _keysAndIdentitiesUp,
    _keysAndIdentitiesDown,
  ),
  const _DwSqlMigration('20260930_000000_dw_setting', _settingUp, _settingDown),
  const _DwSqlMigration(
    '20261009_000001_dw_identity_provider_email',
    _identityProviderEmailUp,
    _identityProviderEmailDown,
  ),
  const _DwSqlMigration(
    '20261009_000002_dw_stored_file_bucket_from_config',
    _storedFileBucketFromConfigUp,
    _storedFileBucketFromConfigDown,
  ),
  const _DwSqlMigration(
    '20261009_000003_dw_auth_key_last_used',
    _authKeyLastUsedUp,
    _authKeyLastUsedDown,
  ),
]);

/// A framework migration written as SQL statements. Its checksum is the hash
/// of those statements, so editing an applied one is caught by the ledger.
final class _DwSqlMigration extends DwDatabaseMigration {
  const _DwSqlMigration(
    this.id,
    this._up,
    this._down, {
    this.supersededChecksums = const {},
  });

  @override
  final String id;
  @override
  final Set<String> supersededChecksums;
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
// later, and its object is found — and deleted — there. Reversed by
// `20261009_000002_dw_stored_file_bucket_from_config` (D-138).
//
// No default and no guess for rows that predate the column: they were uploaded
// to the single bucket `DW_STORAGE_BUCKET` named then, which is neither of the
// two buckets a configuration names now (`molodey` became `molodey-public`),
// and a guessed name would send their links and deletions to a bucket that
// does not hold them — a delete of a missing key succeeds. So such rows stop
// the migration with the statement that records the fact, and a table that
// has them recorded, or has no rows, migrates.
const List<String> _storedFileBucketUp = [
  'ALTER TABLE dw_stored_file ADD COLUMN IF NOT EXISTS bucket text',
  r'''
DO $$
DECLARE
  unknown bigint := (SELECT count(*) FROM dw_stored_file WHERE bucket IS NULL);
BEGIN
  IF unknown > 0 THEN
    RAISE EXCEPTION '% rows of dw_stored_file were uploaded before a file recorded its bucket, and which bucket holds their objects is not something a migration can know: the single bucket DW_STORAGE_BUCKET named then. Record it, then start the server again: ALTER TABLE dw_stored_file ADD COLUMN bucket text; UPDATE dw_stored_file SET bucket = ''<that bucket>'';', unknown;
  END IF;
END
$$''',
  'ALTER TABLE dw_stored_file ALTER COLUMN bucket SET NOT NULL',
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

// Session keys say what they are (an app's sign-in or a personal key made on
// purpose) and carry a label for people; identities say when a code last
// proved them; a code ticket says what its code is for and, for an identifier
// being attached, whose it is.
//
// The defaults exist only to fill rows that predate this migration and are
// dropped at once: the framework writes every one of these columns
// explicitly, and a forgotten write must fail rather than default.
const List<String> _keysAndIdentitiesUp = [
  "ALTER TABLE dw_auth_key ADD COLUMN kind text NOT NULL DEFAULT 'app' "
      "CHECK (kind IN ('app', 'personal'))",
  "ALTER TABLE dw_auth_key ADD COLUMN label text NOT NULL DEFAULT ''",
  'ALTER TABLE dw_auth_key ALTER COLUMN kind DROP DEFAULT',
  'ALTER TABLE dw_auth_key ALTER COLUMN label DROP DEFAULT',
  // Which rows predate the migration's verification cannot be known, so none
  // is claimed verified.
  'ALTER TABLE dw_identity ADD COLUMN verified_at timestamptz',
  "ALTER TABLE dw_code_ticket ADD COLUMN purpose text NOT NULL DEFAULT 'signIn' "
      "CHECK (purpose IN ('signIn', 'attach'))",
  'ALTER TABLE dw_code_ticket ALTER COLUMN purpose DROP DEFAULT',
  // The account attaching the identifier; `NULL` for a sign-in ticket.
  'ALTER TABLE dw_code_ticket ADD COLUMN account_id bigint '
      'REFERENCES dw_account (id) ON DELETE CASCADE',
  "ALTER TABLE dw_code_ticket ADD CONSTRAINT dw_code_ticket_purpose_account "
      "CHECK ((purpose = 'attach') = (account_id IS NOT NULL))",
];

const List<String> _keysAndIdentitiesDown = [
  'ALTER TABLE dw_code_ticket DROP CONSTRAINT dw_code_ticket_purpose_account',
  'ALTER TABLE dw_code_ticket DROP COLUMN account_id',
  'ALTER TABLE dw_code_ticket DROP COLUMN purpose',
  'ALTER TABLE dw_identity DROP COLUMN verified_at',
  'ALTER TABLE dw_auth_key DROP COLUMN label',
  'ALTER TABLE dw_auth_key DROP COLUMN kind',
];

// The app's settings (`ctx.settings`): one row per settings object, named by
// its wire name, holding the JSON the wire carries — only what differs from
// the object's defaults.
const List<String> _settingUp = [
  '''
CREATE TABLE dw_setting (
  area text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
)''',
];

const List<String> _settingDown = ['DROP TABLE dw_setting'];

// The e-mail a provider identity's token proved verified, normalized: what an
// e-mail code sign-in for the same address links to under
// `DwAuthConfig.linkByVerifiedEmail`. Rewritten on every sign-in of the
// identity — `NULL` when the option is off or the token proved none — so it
// fills in for identities made before the option was turned on. `NULL` on
// every code identity.
const List<String> _identityProviderEmailUp = [
  'ALTER TABLE dw_identity ADD COLUMN provider_email text',
  'CREATE INDEX dw_identity_provider_email ON dw_identity (provider_email) '
      'WHERE provider_email IS NOT NULL',
];

const List<String> _identityProviderEmailDown = [
  'DROP INDEX dw_identity_provider_email',
  'ALTER TABLE dw_identity DROP COLUMN provider_email',
];

// A file's bucket is the one the configuration names for its visibility, at
// every use (D-138): the row says what the file is, the configuration where
// files are kept. A recorded bucket was a copy of the configuration and half an
// address — the endpoint was never in it — so a storage moved elsewhere sent
// every link to a bucket that was not there.
//
// A visibility whose rows name more than one bucket stops the migration: its
// objects are in buckets the configuration no longer names, and only copying
// them into one bucket under the same key keeps them readable. The failure
// names each such visibility, its buckets, and the statement that records the
// copy.
const List<String> _storedFileBucketFromConfigUp = [
  r'''
DO $$
DECLARE
  split text := (
    SELECT string_agg(
      format(
        '%s files are in %s — UPDATE dw_stored_file SET bucket = ''<bucket>'' WHERE visibility = %L;',
        visibility, buckets, visibility
      ),
      ' ' ORDER BY visibility
    )
    FROM (
      SELECT visibility,
        string_agg(DISTINCT bucket, ', ' ORDER BY bucket) AS buckets
      FROM dw_stored_file
      GROUP BY visibility
      HAVING count(DISTINCT bucket) > 1
    ) AS visibilities
  );
BEGIN
  IF split IS NOT NULL THEN
    RAISE EXCEPTION 'dw_stored_file keeps files of one visibility in more than one bucket, and from now on a file is read from the one bucket the configuration names for its visibility. Copy those objects, under the same key, into that bucket, record it, then start the server again: %', split;
  END IF;
END
$$''',
  'ALTER TABLE dw_stored_file DROP CONSTRAINT dw_stored_file_object',
  'ALTER TABLE dw_stored_file ADD CONSTRAINT dw_stored_file_object_key '
      'UNIQUE (object_key)',
  'ALTER TABLE dw_stored_file DROP COLUMN bucket',
];

const List<String> _storedFileBucketFromConfigDown = [
  'ALTER TABLE dw_stored_file DROP CONSTRAINT dw_stored_file_object_key',
  'ALTER TABLE dw_stored_file ADD COLUMN bucket text',
  'ALTER TABLE dw_stored_file ADD CONSTRAINT dw_stored_file_object '
      'UNIQUE (bucket, object_key)',
];

// A key's `last_used_at` is `NULL` until its first use, which is always
// written (D-139): a key issued with `now()` there could not be told from one
// used only within its first `keyTouchInterval`. A key whose two times are
// equal was never touched — a touch runs in a later transaction than the
// insert, so its `now()` is later.
const List<String> _authKeyLastUsedUp = [
  'ALTER TABLE dw_auth_key ALTER COLUMN last_used_at DROP NOT NULL',
  'ALTER TABLE dw_auth_key ALTER COLUMN last_used_at DROP DEFAULT',
  'UPDATE dw_auth_key SET last_used_at = NULL '
      'WHERE last_used_at = created_at',
];

const List<String> _authKeyLastUsedDown = [
  'UPDATE dw_auth_key SET last_used_at = created_at '
      'WHERE last_used_at IS NULL',
  'ALTER TABLE dw_auth_key ALTER COLUMN last_used_at SET DEFAULT now()',
  'ALTER TABLE dw_auth_key ALTER COLUMN last_used_at SET NOT NULL',
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
