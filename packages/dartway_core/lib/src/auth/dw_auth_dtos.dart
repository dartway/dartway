import '../dto/dw_server_call.dart';
import '../dto/dw_dto.dart';
import '../protocol/dw_json.dart';
import '../protocol/dw_protocol.dart';

/// The kinds of identifier an account signs in with by one-time code.
enum DwIdentifierKind { phone, email }

/// Asks the server to send a one-time code to an identifier.
///
/// The server normalises the identifier with the project's rule, applies the
/// attempt limits and answers with a ticket. Whether the identifier belongs to
/// an account is not revealed.
final class DwRequestCode extends DwCommand<DwCodeTicket> {
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
    kind: DwJson.decodeEnum(json['kind'], DwIdentifierKind.values),
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
    'expiresAt': DwJson.encodeDateTime(expiresAt),
    'resendAfter': DwJson.encodeDateTime(resendAfter),
  };

  static DwCodeTicket fromJson(Map<String, Object?> json) => DwCodeTicket(
    id: json['id']! as String,
    expiresAt: DwJson.decodeDateTime(json['expiresAt']),
    resendAfter: DwJson.decodeDateTime(json['resendAfter']),
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
/// consents) to its account-created hook; it is ignored for an existing account.
final class DwVerifyCode extends DwCommand<DwSession> {
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
        : DwJson.decodeMap(json['registration'], (v) => v! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is DwVerifyCode && other.ticketId == ticketId && other.code == code;

  @override
  int get hashCode => Object.hash(ticketId, code);
}

/// A signed-in session: the account and the token the client keeps and sends
/// as `Authorization: Bearer <token>` and in the live `auth` message.
final class DwSession extends DwDataObject {
  const DwSession({
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
  String get dwTypeName => 'DwSession';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'token': token,
    if (isNewAccount) 'isNewAccount': true,
  };

  static DwSession fromJson(Map<String, Object?> json) => DwSession(
    id: json['id']! as int,
    token: json['token']! as String,
    isNewAccount: json['isNewAccount'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is DwSession && other.id == id && other.token == token;

  @override
  int get hashCode => Object.hash(id, token);
}

/// Revokes the caller's session key; the server closes the live
/// subscriptions of connections authenticated with it.
final class DwSignOut extends DwCommand<void> {
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

/// The auth DTOs, registered in [DwProtocol.core].
const List<DwDtoEntry> dwAuthDtoEntries = [
  DwDtoEntry<DwRequestCode>('DwRequestCode', DwRequestCode.fromJson),
  DwDtoEntry<DwCodeTicket>('DwCodeTicket', DwCodeTicket.fromJson),
  DwDtoEntry<DwVerifyCode>('DwVerifyCode', DwVerifyCode.fromJson),
  DwDtoEntry<DwSession>('DwSession', DwSession.fromJson),
  DwDtoEntry<DwSignOut>('DwSignOut', DwSignOut.fromJson),
];
