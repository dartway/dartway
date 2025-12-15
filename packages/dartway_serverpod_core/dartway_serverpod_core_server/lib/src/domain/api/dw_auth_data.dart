import 'package:serverpod/serverpod.dart';

class DwAuthData implements SerializableModel, ProtocolSerialization {
  static SerializationManagerServer get _protocol =>
      Serverpod.instance.serializationManager;

  DwAuthData({
    required this.userProfile,
    required this.key,
    required this.keyId,
  }) : className = _protocol.getClassNameForObject(userProfile) ?? 'unknown';

  final String className;
  final String key;
  final int keyId;
  final TableRow userProfile;

  String get dwMappingClassname => className.split('.').last;

  factory DwAuthData.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DwAuthData(
      key: jsonSerialization['key'],
      keyId: jsonSerialization['keyId'],
      userProfile: _protocol.deserializeByClassName(jsonSerialization),
    );
  }

  @override
  toJson() {
    return {
      'className': className,
      'key': key,
      'keyId': keyId,
      'data': userProfile.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      'className': className,
      'key': key,
      'keyId': keyId,
      'data': userProfile.toJson(),
    };
  }

  DwAuthData copyWith({
    TableRow? userProfile,
    String? key,
    int? keyId,
  }) {
    return DwAuthData(
      key: key ?? this.key,
      keyId: keyId ?? this.keyId,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}
