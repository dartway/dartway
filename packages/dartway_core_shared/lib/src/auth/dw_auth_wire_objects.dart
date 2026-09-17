import '../protocol/dw_json_codec.dart';
import '../protocol/dw_wire_protocol.dart';
import '../result/dw_call_refusal.dart';
import '../wire/dw_server_call.dart';
import '../wire/dw_wire_object.dart';

/// The kinds of identifier an account signs in with by one-time code.
enum DwIdentifierKind { phone, email }

/// Asks the server to send a one-time code to an identifier.
///
/// The server normalises the identifier with the project's rule, applies the
/// attempt limits and answers with a ticket. Whether the identifier belongs to
/// an account is not revealed.
final class DwRequestCode extends DwActionCommand<DwCodeTicket> {
  const DwRequestCode({required this.kind, required this.identifier});

  final DwIdentifierKind kind;
  final String identifier;

  @override
  String get dwTypeName => 'DwRequestCode';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'identifier': identifier,
  };

  static DwRequestCode fromJson(Map<String, Object?> json) => DwRequestCode(
    kind: DwJsonCodec.decodeEnum(json['kind'], DwIdentifierKind.values),
    identifier: json['identifier']! as String,
  );

  @override
  bool operator ==(Object other) =>
      other is DwRequestCode &&
      other.kind == kind &&
      other.identifier == identifier;

  @override
  int get hashCode => Object.hash(kind, identifier);
}

/// A sent code, identified by [id]; verification refers to it.
final class DwCodeTicket extends DwDataObject {
  const DwCodeTicket({
    required this.id,
    required this.expiresAt,
    required this.resendAfter,
  });

  @override
  final String id;
  final DateTime expiresAt;
  final DateTime resendAfter;

  @override
  String get dwTypeName => 'DwCodeTicket';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'expiresAt': DwJsonCodec.encodeDateTime(expiresAt),
    'resendAfter': DwJsonCodec.encodeDateTime(resendAfter),
  };

  static DwCodeTicket fromJson(Map<String, Object?> json) => DwCodeTicket(
    id: json['id']! as String,
    expiresAt: DwJsonCodec.decodeDateTime(json['expiresAt']),
    resendAfter: DwJsonCodec.decodeDateTime(json['resendAfter']),
  );

  @override
  bool operator ==(Object other) =>
      other is DwCodeTicket &&
      other.id == id &&
      other.expiresAt == expiresAt &&
      other.resendAfter == resendAfter;

  @override
  int get hashCode => Object.hash(id, expiresAt, resendAfter);
}

/// Verifies a code and signs in; creates the account when the identifier has
/// none. [registration] carries what the project collects at sign-up (name,
/// consents) to its account-created hook; it is ignored for an existing
/// account.
///
/// Only a ticket of [DwRequestCode] signs in: one of
/// [DwRequestIdentifierCode] reads as expired here. The session it answers is
/// a new key of kind [DwSessionKeyKind.app].
final class DwVerifyCode extends DwActionCommand<DwAuthSession> {
  const DwVerifyCode({
    required this.ticketId,
    required this.code,
    this.registration = const {},
  });

  final String ticketId;
  final String code;
  final Map<String, String> registration;

  @override
  String get dwTypeName => 'DwVerifyCode';

  @override
  Map<String, Object?> toJson() => {
    'ticketId': ticketId,
    'code': code,
    if (registration.isNotEmpty) 'registration': registration,
  };

  static DwVerifyCode fromJson(Map<String, Object?> json) => DwVerifyCode(
    ticketId: json['ticketId']! as String,
    code: json['code']! as String,
    registration: json['registration'] == null
        ? const {}
        : DwJsonCodec.decodeMap(json['registration'], (v) => v! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is DwVerifyCode && other.ticketId == ticketId && other.code == code;

  @override
  int get hashCode => Object.hash(ticketId, code);
}

/// A signed-in session: the account and the token the client keeps and sends
/// as `Authorization: Bearer <token>` and in the live `auth` message.
final class DwAuthSession extends DwDataObject {
  const DwAuthSession({
    required this.id,
    required this.token,
    required this.isNewAccount,
  });

  /// The account id.
  @override
  final int id;
  final String token;
  final bool isNewAccount;

  @override
  String get dwTypeName => 'DwAuthSession';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'token': token,
    if (isNewAccount) 'isNewAccount': true,
  };

  static DwAuthSession fromJson(Map<String, Object?> json) => DwAuthSession(
    id: json['id']! as int,
    token: json['token']! as String,
    isNewAccount: json['isNewAccount'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is DwAuthSession && other.id == id && other.token == token;

  @override
  int get hashCode => Object.hash(id, token);
}

/// Revokes the caller's session key; the server closes the live
/// subscriptions of connections authenticated with it.
final class DwSignOut extends DwActionCommand<void> {
  const DwSignOut();

  @override
  String get dwTypeName => 'DwSignOut';

  @override
  Map<String, Object?> toJson() => const {};

  static DwSignOut fromJson(Map<String, Object?> json) => const DwSignOut();

  @override
  bool operator ==(Object other) => other is DwSignOut;

  @override
  int get hashCode => 0;
}

/// Deletes the caller's account and everything the framework keeps for it:
/// identities, session keys (every session of the account ends), stored
/// files, push devices. The project's own data goes in
/// `DwAuthConfig.onAccountDeleting`, in the same transaction.
///
/// App stores require it: an app that lets people create an account must let
/// them delete it inside the app (App Store Review Guideline 5.1.1(v)).
final class DwDeleteMyAccount extends DwActionCommand<void> {
  const DwDeleteMyAccount();

  @override
  String get dwTypeName => 'DwDeleteMyAccount';

  @override
  Map<String, Object?> toJson() => const {};

  static DwDeleteMyAccount fromJson(Map<String, Object?> json) =>
      const DwDeleteMyAccount();

  @override
  bool operator ==(Object other) => other is DwDeleteMyAccount;

  @override
  int get hashCode => 1;
}

/// What a session key is for.
///
/// Every token the server accepts is a session key of an account; the kind
/// says how it came to exist, so a server can tell the app from a key a person
/// made for a tool (`DwCallContext.sessionKey`) without trusting anything the
/// client sends.
enum DwSessionKeyKind {
  /// Made by a sign-in with a one-time code: an installation of the app.
  app,

  /// Made on purpose by `DwAccountService.issueKey` — a personal access key
  /// for a tool (an MCP client, a script).
  personal,
}

/// A session key of an account, as the framework describes it: never its
/// token, which is shown once when the key is made and stored only as a hash.
final class DwSessionKeyInfo extends DwDataObject {
  const DwSessionKeyInfo({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.label,
    required this.createdAt,
    required this.lastUsedAt,
    this.revokedAt,
  });

  /// The key's id (`dw_auth_key.id`): what `DwAccountService.revokeKey`
  /// takes.
  @override
  final int id;
  final int accountId;
  final DwSessionKeyKind kind;

  /// For people: the name given to a personal key, or what the app said about
  /// itself when it signed in (its `Dw-App-Version` and user agent). Never a
  /// secret, and never trusted as an identity — only [kind] is the server's.
  final String label;
  final DateTime createdAt;

  /// When a call last used the key, written at most once per
  /// `DwAuthConfig.keyTouchInterval`.
  final DateTime lastUsedAt;

  /// When the key was revoked; `null` while it signs calls in.
  final DateTime? revokedAt;

  /// The longest [label] the server stores.
  static const int maxLabelLength = 200;

  bool get isRevoked => revokedAt != null;

  @override
  String get dwTypeName => 'DwSessionKeyInfo';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'kind': kind.name,
    'label': label,
    'createdAt': DwJsonCodec.encodeDateTime(createdAt),
    'lastUsedAt': DwJsonCodec.encodeDateTime(lastUsedAt),
    if (revokedAt case final revokedAt?)
      'revokedAt': DwJsonCodec.encodeDateTime(revokedAt),
  };

  static DwSessionKeyInfo fromJson(Map<String, Object?> json) =>
      DwSessionKeyInfo(
        id: json['id']! as int,
        accountId: json['accountId']! as int,
        kind: DwJsonCodec.decodeEnum(json['kind'], DwSessionKeyKind.values),
        label: json['label']! as String,
        createdAt: DwJsonCodec.decodeDateTime(json['createdAt']),
        lastUsedAt: DwJsonCodec.decodeDateTime(json['lastUsedAt']),
        revokedAt: json['revokedAt'] == null
            ? null
            : DwJsonCodec.decodeDateTime(json['revokedAt']),
      );

  @override
  bool operator ==(Object other) =>
      other is DwSessionKeyInfo &&
      other.id == id &&
      other.accountId == accountId &&
      other.kind == kind &&
      other.label == label &&
      other.createdAt == createdAt &&
      other.lastUsedAt == lastUsedAt &&
      other.revokedAt == revokedAt;

  @override
  int get hashCode =>
      Object.hash(id, accountId, kind, label, createdAt, lastUsedAt, revokedAt);

  @override
  String toString() =>
      'DwSessionKeyInfo($id, account $accountId, ${kind.name}, "$label"'
      '${revokedAt == null ? '' : ', revoked'})';
}

/// An identifier an account signs in with.
final class DwIdentityInfo extends DwDataObject {
  const DwIdentityInfo({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.value,
    required this.createdAt,
    this.verifiedAt,
  });

  /// The identity's id (`dw_identity.id`); it survives a move to another
  /// account and a replacement of its value.
  @override
  final int id;
  final int accountId;
  final DwIdentifierKind kind;

  /// The normalized identifier (`DwAuthConfig.normalize`).
  final String value;
  final DateTime createdAt;

  /// When a one-time code sent to [value] was last confirmed for this
  /// account — by a sign-in or by `DwConfirmIdentifier`. `null` for an
  /// identifier a tool attached (`DwAccountService.ensure`) that has not
  /// signed in since.
  final DateTime? verifiedAt;

  @override
  String get dwTypeName => 'DwIdentityInfo';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'kind': kind.name,
    'value': value,
    'createdAt': DwJsonCodec.encodeDateTime(createdAt),
    if (verifiedAt case final verifiedAt?)
      'verifiedAt': DwJsonCodec.encodeDateTime(verifiedAt),
  };

  static DwIdentityInfo fromJson(Map<String, Object?> json) => DwIdentityInfo(
    id: json['id']! as int,
    accountId: json['accountId']! as int,
    kind: DwJsonCodec.decodeEnum(json['kind'], DwIdentifierKind.values),
    value: json['value']! as String,
    createdAt: DwJsonCodec.decodeDateTime(json['createdAt']),
    verifiedAt: json['verifiedAt'] == null
        ? null
        : DwJsonCodec.decodeDateTime(json['verifiedAt']),
  );

  @override
  bool operator ==(Object other) =>
      other is DwIdentityInfo &&
      other.id == id &&
      other.accountId == accountId &&
      other.kind == kind &&
      other.value == value &&
      other.createdAt == createdAt &&
      other.verifiedAt == verifiedAt;

  @override
  int get hashCode =>
      Object.hash(id, accountId, kind, value, createdAt, verifiedAt);

  @override
  String toString() =>
      'DwIdentityInfo($id, account $accountId, ${kind.name} $value)';
}

/// Asks the server to send a one-time code to an identifier the signed-in
/// caller wants to attach to their account, or to change theirs to — without
/// signing in again. Confirmed with [DwConfirmIdentifier].
///
/// Everything sign-in does applies: the same normalization, the same limits
/// per identifier (the two commands share them), the same delivery and fixed
/// code. As with [DwRequestCode], the answer does not reveal whether the
/// identifier belongs to an account; only a confirmed code learns that.
final class DwRequestIdentifierCode extends DwActionCommand<DwCodeTicket> {
  const DwRequestIdentifierCode({required this.kind, required this.identifier});

  final DwIdentifierKind kind;
  final String identifier;

  @override
  String get dwTypeName => 'DwRequestIdentifierCode';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'identifier': identifier,
  };

  static DwRequestIdentifierCode fromJson(Map<String, Object?> json) =>
      DwRequestIdentifierCode(
        kind: DwJsonCodec.decodeEnum(json['kind'], DwIdentifierKind.values),
        identifier: json['identifier']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is DwRequestIdentifierCode &&
      other.kind == kind &&
      other.identifier == identifier;

  @override
  int get hashCode => Object.hash(DwRequestIdentifierCode, kind, identifier);
}

/// Confirms the code of a [DwRequestIdentifierCode] ticket and attaches its
/// identifier to the caller's account — or, with [replace], puts it in place
/// of the caller's identifiers of the same kind. Answers the identity.
///
/// Only the account that requested the ticket can confirm it, and a sign-in
/// ticket cannot be confirmed here (nor this one signed in with). A wrong code
/// counts against the ticket's attempts, as in [DwVerifyCode]. A right code
/// for an identifier that belongs to another account is refused with
/// [DwAuthRefusal.identifierTaken] on field `code`, and the ticket is used up.
final class DwConfirmIdentifier extends DwActionCommand<DwIdentityInfo> {
  const DwConfirmIdentifier({
    required this.ticketId,
    required this.code,
    this.replace = false,
  });

  final String ticketId;
  final String code;

  /// Whether the identifier replaces the caller's identifiers of its kind
  /// (a changed phone number) rather than joining them.
  final bool replace;

  @override
  String get dwTypeName => 'DwConfirmIdentifier';

  @override
  Map<String, Object?> toJson() => {
    'ticketId': ticketId,
    'code': code,
    if (replace) 'replace': true,
  };

  static DwConfirmIdentifier fromJson(Map<String, Object?> json) =>
      DwConfirmIdentifier(
        ticketId: json['ticketId']! as String,
        code: json['code']! as String,
        replace: json['replace'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is DwConfirmIdentifier &&
      other.ticketId == ticketId &&
      other.code == code &&
      other.replace == replace;

  @override
  int get hashCode => Object.hash(ticketId, code, replace);
}

/// The framework's refusals of identifier changes, beside `DwCoreRefusal`
/// (a separate enum, so a project switching exhaustively over the core codes
/// keeps compiling); the codes share the `dw.` namespace.
enum DwAuthRefusal implements DwRefusalCode {
  /// The confirmed identifier already belongs to another account. Told only
  /// to whoever proved they receive its codes — what a sign-in with it would
  /// tell them too.
  identifierTaken('dw.identifierTaken');

  const DwAuthRefusal(this.code);

  @override
  final String code;
}

/// The auth DTOs, registered in [DwWireProtocol.core].
const List<DwProtocolEntry> dwAuthProtocolEntries = [
  DwProtocolEntry<DwRequestCode>('DwRequestCode', DwRequestCode.fromJson),
  DwProtocolEntry<DwCodeTicket>('DwCodeTicket', DwCodeTicket.fromJson),
  DwProtocolEntry<DwVerifyCode>('DwVerifyCode', DwVerifyCode.fromJson),
  DwProtocolEntry<DwAuthSession>('DwAuthSession', DwAuthSession.fromJson),
  DwProtocolEntry<DwSignOut>('DwSignOut', DwSignOut.fromJson),
  DwProtocolEntry<DwDeleteMyAccount>(
    'DwDeleteMyAccount',
    DwDeleteMyAccount.fromJson,
  ),
  DwProtocolEntry<DwRequestIdentifierCode>(
    'DwRequestIdentifierCode',
    DwRequestIdentifierCode.fromJson,
  ),
  DwProtocolEntry<DwConfirmIdentifier>(
    'DwConfirmIdentifier',
    DwConfirmIdentifier.fromJson,
  ),
  DwProtocolEntry<DwIdentityInfo>('DwIdentityInfo', DwIdentityInfo.fromJson),
  DwProtocolEntry<DwSessionKeyInfo>(
    'DwSessionKeyInfo',
    DwSessionKeyInfo.fromJson,
  ),
];
