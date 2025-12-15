/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'feed_post/feed_post.dart' as _i2;
import 'user_profile/user_gender.dart' as _i3;
import 'user_profile/user_profile.dart' as _i4;
import 'water_intake.dart' as _i5;
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as _i6;
import 'package:serverpod_auth_client/serverpod_auth_client.dart' as _i7;
export 'feed_post/feed_post.dart';
export 'user_profile/user_gender.dart';
export 'user_profile/user_profile.dart';
export 'water_intake.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
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
    try {
      return _i7.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is _i2.FeedPost) {
      return 'FeedPost';
    }
    if (data is _i3.UserGender) {
      return 'UserGender';
    }
    if (data is _i4.UserProfile) {
      return 'UserProfile';
    }
    if (data is _i5.WaterIntake) {
      return 'WaterIntake';
    }
    className = _i6.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'dartway_serverpod_core.$className';
    }
    className = _i7.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth.$className';
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
    if (dataClassName.startsWith('serverpod_auth.')) {
      data['className'] = dataClassName.substring(15);
      return _i7.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }
}
