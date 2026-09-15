import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The service that issued a device token, and so the only one that can
/// deliver to it.
///
/// Stored with the token and never guessed: a token of one transport sent to
/// another is answered with an error the other one's rules read as "invalid",
/// and a live registration is deleted (the RuStore token that FCM called
/// `UNREGISTERED`).
enum DwPushTransport {
  /// Firebase Cloud Messaging: Android, iOS (through APNs) and the web.
  fcm,

  /// RuStore push: Android devices with RuStore.
  rustore,
}

/// The platform a device token was issued on — for operators, and for a
/// project that sends differently per platform.
enum DwPushPlatform { android, ios, web, macos, other }

/// Refusals of the push calls.
enum DwPushRefusal implements DwRefusalCode {
  /// The token is empty, longer than [DwRegisterPushToken.maxTokenLength], or
  /// holds whitespace or control characters; the field is `token`.
  tokenInvalid('dw.pushTokenInvalid');

  const DwPushRefusal(this.code);

  @override
  final String code;
}

/// Registers this device's push token for the signed-in caller.
///
/// The account is never a field: the server takes the caller's, and the
/// session key the call was signed in with. A device signed out anywhere —
/// its key revoked — receives nothing more for that account, even when the
/// app never got to unregister. The same token registered by another account
/// moves to it (a phone changing hands), and registering it again refreshes
/// it.
final class DwRegisterPushToken extends DwActionCommand<void>
    implements DwSelfValidating {
  const DwRegisterPushToken({
    required this.transport,
    required this.token,
    required this.platform,
  });

  /// FCM tokens are ~160 characters, RuStore ones shorter; anything near
  /// this is not a token.
  static const int maxTokenLength = 1024;

  final DwPushTransport transport;
  final String token;
  final DwPushPlatform platform;

  @override
  List<DwCallRefusal> validate() => [
    if (!isTokenAcceptable(token))
      DwCallRefusal(DwPushRefusal.tokenInvalid, field: 'token'),
  ];

  /// Whether [token] can be a provider token: non-empty, bounded, and
  /// without whitespace or control characters — which no provider issues,
  /// and which would make one device two rows.
  static bool isTokenAcceptable(String token) =>
      token.isNotEmpty &&
      token.length <= maxTokenLength &&
      !token.codeUnits.any((unit) => unit <= 0x20 || unit == 0x7f);

  @override
  String get dwTypeName => 'DwRegisterPushToken';

  @override
  Map<String, Object?> toJson() => {
    'transport': transport.name,
    'token': token,
    'platform': platform.name,
  };

  static DwRegisterPushToken fromJson(Map<String, Object?> json) =>
      DwRegisterPushToken(
        transport: DwJsonCodec.decodeEnum(
          json['transport'],
          DwPushTransport.values,
        ),
        token: json['token']! as String,
        platform: DwJsonCodec.decodeEnum(
          json['platform'],
          DwPushPlatform.values,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is DwRegisterPushToken &&
      other.transport == transport &&
      other.token == token &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(transport, token, platform);

  @override
  String toString() =>
      'DwRegisterPushToken(${transport.name}, ${platform.name}, '
      '${token.length} characters)';
}

/// Removes the caller's registration of [token] — the user turned
/// notifications off on this device. A token that is not the caller's is
/// left alone, and the answer is the same: a caller learns nothing about
/// other accounts' devices.
final class DwUnregisterPushToken extends DwActionCommand<void>
    implements DwSelfValidating {
  const DwUnregisterPushToken({required this.token});

  final String token;

  @override
  List<DwCallRefusal> validate() => [
    if (!DwRegisterPushToken.isTokenAcceptable(token))
      DwCallRefusal(DwPushRefusal.tokenInvalid, field: 'token'),
  ];

  @override
  String get dwTypeName => 'DwUnregisterPushToken';

  @override
  Map<String, Object?> toJson() => {'token': token};

  static DwUnregisterPushToken fromJson(Map<String, Object?> json) =>
      DwUnregisterPushToken(token: json['token']! as String);

  @override
  bool operator ==(Object other) =>
      other is DwUnregisterPushToken && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'DwUnregisterPushToken(${token.length} characters)';
}

/// The push calls, for the project's protocol:
///
/// ```dart
/// final appProtocol = DwWireProtocol(
///   dwPushProtocolEntries,
///   include: dartwayExampleProtocol,
/// );
/// ```
const List<DwProtocolEntry> dwPushProtocolEntries = [
  DwProtocolEntry<DwRegisterPushToken>(
    'DwRegisterPushToken',
    DwRegisterPushToken.fromJson,
  ),
  DwProtocolEntry<DwUnregisterPushToken>(
    'DwUnregisterPushToken',
    DwUnregisterPushToken.fromJson,
  ),
];
