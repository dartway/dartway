import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

/// The framework's rows of session keys and identities, read and written in
/// one place: every query naming `dw_auth_key` or `dw_identity` lives here or
/// next to the code that owns the flow, never in a project.
@internal
abstract final class DwAuthStore {
  static final Random _random = Random.secure();

  /// The columns [keyOf] reads.
  static const String keyColumns =
      'id, account_id, kind, label, created_at, last_used_at, revoked_at';

  /// The columns [identityOf] reads.
  static const String identityColumns =
      'id, account_id, kind, value, created_at, verified_at';

  static DwSessionKeyInfo keyOf(DwResultRow row) => DwSessionKeyInfo(
    id: row.get<int>('id'),
    accountId: row.get<int>('account_id'),
    kind: DwSessionKeyKind.values.byName(row.get<String>('kind')),
    label: row.get<String>('label'),
    createdAt: row.get<DateTime>('created_at'),
    lastUsedAt: row.get<DateTime>('last_used_at'),
    revokedAt: row['revoked_at'] as DateTime?,
  );

  static DwIdentityInfo identityOf(DwResultRow row) => DwIdentityInfo(
    id: row.get<int>('id'),
    accountId: row.get<int>('account_id'),
    kind: DwIdentifierKind.values.byName(row.get<String>('kind')),
    value: row.get<String>('value'),
    createdAt: row.get<DateTime>('created_at'),
    verifiedAt: row['verified_at'] as DateTime?,
  );

  /// [key] as last used at [at].
  static DwSessionKeyInfo touched(DwSessionKeyInfo key, DateTime at) =>
      DwSessionKeyInfo(
        id: key.id,
        accountId: key.accountId,
        kind: key.kind,
        label: key.label,
        createdAt: key.createdAt,
        lastUsedAt: at,
        revokedAt: key.revokedAt,
      );

  /// SHA-256 of a token: the only form a token is stored or cached in.
  static Uint8List hashToken(String token) =>
      Uint8List.fromList(sha256.convert(utf8.encode(token)).bytes);

  /// [bytes] random bytes, base64url without padding.
  static String randomToken(int bytes) => base64Url
      .encode(List.generate(bytes, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  /// Makes a session key of [accountId] and returns it with its token — the
  /// one moment the token exists outside the client. `null` when the account
  /// does not exist.
  ///
  /// 256 random bits: a token is a bearer credential and nothing else guards
  /// it.
  static Future<({DwSessionKeyInfo key, String token})?> insertKey(
    DwDatabaseHandle db, {
    required int accountId,
    required DwSessionKeyKind kind,
    required String label,
  }) async {
    final token = randomToken(32);
    // Inserted from the account row, so a missing account is an empty answer
    // rather than a foreign key violation that would abort the caller's
    // transaction.
    final rows = await db.query(
      'INSERT INTO dw_auth_key (account_id, token_hash, kind, label) '
      'SELECT id, @hash, @kind, @label FROM dw_account WHERE id = @account '
      'RETURNING $keyColumns',
      params: {
        'account': accountId,
        'hash': hashToken(token),
        'kind': kind.name,
        'label': label,
      },
    );
    if (rows.isEmpty) return null;
    return (key: keyOf(rows.single), token: token);
  }

  /// The label of a key made by signing in: what the app said about itself —
  /// its `Dw-App-Version` and its user agent, joined by ` · ` — made safe to
  /// show (no control characters, runs of whitespace folded) and cut to
  /// [DwSessionKeyInfo.maxLabelLength]. Empty when the app said nothing.
  ///
  /// Both come from the client, so the label describes and never identifies:
  /// a server tells the app from a personal key by `DwSessionKeyInfo.kind`.
  static String appLabel({String? appVersion, String? userAgent}) {
    final label = [appVersion, userAgent]
        .map((part) => (part ?? '').replaceAll(_unsafe, ' ').trim())
        .where((part) => part.isNotEmpty)
        .join(' · ')
        .replaceAll(_spaces, ' ');
    if (label.length <= DwSessionKeyInfo.maxLabelLength) return label;
    var end = DwSessionKeyInfo.maxLabelLength;
    // Not between the halves of a surrogate pair.
    if ((label.codeUnitAt(end - 1) & 0xfc00) == 0xd800) end--;
    return label.substring(0, end);
  }

  static final RegExp _unsafe = RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]');
  static final RegExp _spaces = RegExp(r'\s{2,}');

  /// The label of a key made on purpose: trimmed, and refused with
  /// [ArgumentError] when empty, over [DwSessionKeyInfo.maxLabelLength] or
  /// holding control characters — a list of keys whose names cannot be told
  /// apart or shown is a list nobody can revoke from with confidence.
  static String personalLabel(String raw) {
    final label = raw.trim();
    if (label.isEmpty) {
      throw ArgumentError.value(raw, 'label', 'a key needs a label');
    }
    if (label.length > DwSessionKeyInfo.maxLabelLength) {
      throw ArgumentError.value(
        raw,
        'label',
        'longer than ${DwSessionKeyInfo.maxLabelLength} characters',
      );
    }
    if (_unsafe.hasMatch(label)) {
      throw ArgumentError.value(raw, 'label', 'holds control characters');
    }
    return label;
  }
}
