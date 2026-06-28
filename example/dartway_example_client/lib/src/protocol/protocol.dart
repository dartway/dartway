/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'feed_post/feed_post.dart' as _i2;
import 'user_profile/user_gender.dart' as _i3;
import 'user_profile/user_profile.dart' as _i4;
import 'water_intake.dart' as _i5;
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as _i6;
export 'feed_post/feed_post.dart';
export 'user_profile/user_gender.dart';
export 'user_profile/user_profile.dart';
export 'water_intake.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i2.FeedPost) {
      return _i2.FeedPost.fromJson(data) as T;
    }
    if (t == _i3.UserGender) {
      return _i3.UserGender.fromJson(data) as T;
    }
    if (t == _i4.UserProfile) {
      return _i4.UserProfile.fromJson(data) as T;
    }
    if (t == _i5.WaterIntake) {
      return _i5.WaterIntake.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.FeedPost?>()) {
      return (data != null ? _i2.FeedPost.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.UserGender?>()) {
      return (data != null ? _i3.UserGender.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.UserProfile?>()) {
      return (data != null ? _i4.UserProfile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.WaterIntake?>()) {
      return (data != null ? _i5.WaterIntake.fromJson(data) : null) as T;
    }
    try {
      return _i6.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.FeedPost => 'FeedPost',
      _i3.UserGender => 'UserGender',
      _i4.UserProfile => 'UserProfile',
      _i5.WaterIntake => 'WaterIntake',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'dartway_example.',
        '',
      );
    }

    switch (data) {
      case _i2.FeedPost():
        return 'FeedPost';
      case _i3.UserGender():
        return 'UserGender';
      case _i4.UserProfile():
        return 'UserProfile';
      case _i5.WaterIntake():
        return 'WaterIntake';
    }
    className = _i6.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'dartway_serverpod_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'FeedPost') {
      return deserialize<_i2.FeedPost>(data['data']);
    }
    if (dataClassName == 'UserGender') {
      return deserialize<_i3.UserGender>(data['data']);
    }
    if (dataClassName == 'UserProfile') {
      return deserialize<_i4.UserProfile>(data['data']);
    }
    if (dataClassName == 'WaterIntake') {
      return deserialize<_i5.WaterIntake>(data['data']);
    }
    if (dataClassName.startsWith('dartway_serverpod_core.')) {
      data['className'] = dataClassName.substring(23);
      return _i6.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i6.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
