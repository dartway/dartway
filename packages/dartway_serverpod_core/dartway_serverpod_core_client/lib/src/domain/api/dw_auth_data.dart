import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

class DwAuthData implements SerializableModel, ProtocolSerialization {
  static String getClassNameForObject(SerializableModel model) {
    return DwCoreServerpodClient.protocol.getClassNameForObject(model) ??
        'unknown';
  }

  DwAuthData({
    required this.userProfile,
    required this.userId,
    required this.key,
    required this.keyId,
  }) : className =
           DwCoreServerpodClient.protocol.getClassNameForObject(userProfile) ??
           'unknown';

  final String className;
  final SerializableModel userProfile;
  final int? userId;
  final String key;
  final int keyId;

  String get dwMappingClassname => className.split('.').last;

  factory DwAuthData.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAuthData(
      userId: jsonSerialization['data']['id'],
      userProfile: DwCoreServerpodClient.protocol.deserializeByClassName(
        jsonSerialization,
      ),
      key: jsonSerialization['key'],
      keyId: jsonSerialization['keyId'],
    );
  }

  @override
  toJson() {
    return {
      'className': DwCoreServerpodClient.protocol.getClassNameForObject(
        userProfile,
      ),
      'data': userProfile.toJson(),
      'key': key,
      'keyId': keyId,
    };
  }

  @override
  toJsonForProtocol() {
    return {
      'className': DwCoreServerpodClient.protocol.getClassNameForObject(
        userProfile,
      ),
      'data': userProfile.toJson(),
      'key': key,
      'keyId': keyId,
    };
  }

  /// Необходим для работы методов copyWith в ChatInitialData и DwAppNotification
  DwAuthData copyWith({
    SerializableModel? userProfile,
    int? userId,
    String? key,
    int? keyId,
  }) {
    return DwAuthData(
      userProfile: userProfile ?? this.userProfile,
      userId: userId ?? this.userId,
      key: key ?? this.key,
      keyId: keyId ?? this.keyId,
    );
  }
}
