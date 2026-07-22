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
import 'booking/enums/booking_status.dart' as _i2;
import 'booking/session_booking.dart' as _i3;
import 'booking/session_review.dart' as _i4;
import 'chat/chat_channel.dart' as _i5;
import 'chat/chat_message.dart' as _i6;
import 'news/news_post.dart' as _i7;
import 'schedule/club_service.dart' as _i8;
import 'schedule/club_session.dart' as _i9;
import 'settings/app_setting.dart' as _i10;
import 'user_profile/enums/user_role.dart' as _i11;
import 'user_profile/user_gender.dart' as _i12;
import 'user_profile/user_profile.dart' as _i13;
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as _i14;
import 'package:dartway_push_client/dartway_push_client.dart' as _i15;
export 'booking/enums/booking_status.dart';
export 'booking/session_booking.dart';
export 'booking/session_review.dart';
export 'chat/chat_channel.dart';
export 'chat/chat_message.dart';
export 'news/news_post.dart';
export 'schedule/club_service.dart';
export 'schedule/club_session.dart';
export 'settings/app_setting.dart';
export 'user_profile/enums/user_role.dart';
export 'user_profile/user_gender.dart';
export 'user_profile/user_profile.dart';
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

    if (t == _i2.BookingStatus) {
      return _i2.BookingStatus.fromJson(data) as T;
    }
    if (t == _i3.SessionBooking) {
      return _i3.SessionBooking.fromJson(data) as T;
    }
    if (t == _i4.SessionReview) {
      return _i4.SessionReview.fromJson(data) as T;
    }
    if (t == _i5.ChatChannel) {
      return _i5.ChatChannel.fromJson(data) as T;
    }
    if (t == _i6.ChatMessage) {
      return _i6.ChatMessage.fromJson(data) as T;
    }
    if (t == _i7.NewsPost) {
      return _i7.NewsPost.fromJson(data) as T;
    }
    if (t == _i8.ClubService) {
      return _i8.ClubService.fromJson(data) as T;
    }
    if (t == _i9.ClubSession) {
      return _i9.ClubSession.fromJson(data) as T;
    }
    if (t == _i10.AppSetting) {
      return _i10.AppSetting.fromJson(data) as T;
    }
    if (t == _i11.UserRole) {
      return _i11.UserRole.fromJson(data) as T;
    }
    if (t == _i12.UserGender) {
      return _i12.UserGender.fromJson(data) as T;
    }
    if (t == _i13.UserProfile) {
      return _i13.UserProfile.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.BookingStatus?>()) {
      return (data != null ? _i2.BookingStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.SessionBooking?>()) {
      return (data != null ? _i3.SessionBooking.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.SessionReview?>()) {
      return (data != null ? _i4.SessionReview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.ChatChannel?>()) {
      return (data != null ? _i5.ChatChannel.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.ChatMessage?>()) {
      return (data != null ? _i6.ChatMessage.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.NewsPost?>()) {
      return (data != null ? _i7.NewsPost.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.ClubService?>()) {
      return (data != null ? _i8.ClubService.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.ClubSession?>()) {
      return (data != null ? _i9.ClubSession.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.AppSetting?>()) {
      return (data != null ? _i10.AppSetting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.UserRole?>()) {
      return (data != null ? _i11.UserRole.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.UserGender?>()) {
      return (data != null ? _i12.UserGender.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.UserProfile?>()) {
      return (data != null ? _i13.UserProfile.fromJson(data) : null) as T;
    }
    try {
      return _i14.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i15.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.BookingStatus => 'BookingStatus',
      _i3.SessionBooking => 'SessionBooking',
      _i4.SessionReview => 'SessionReview',
      _i5.ChatChannel => 'ChatChannel',
      _i6.ChatMessage => 'ChatMessage',
      _i7.NewsPost => 'NewsPost',
      _i8.ClubService => 'ClubService',
      _i9.ClubSession => 'ClubSession',
      _i10.AppSetting => 'AppSetting',
      _i11.UserRole => 'UserRole',
      _i12.UserGender => 'UserGender',
      _i13.UserProfile => 'UserProfile',
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
      case _i2.BookingStatus():
        return 'BookingStatus';
      case _i3.SessionBooking():
        return 'SessionBooking';
      case _i4.SessionReview():
        return 'SessionReview';
      case _i5.ChatChannel():
        return 'ChatChannel';
      case _i6.ChatMessage():
        return 'ChatMessage';
      case _i7.NewsPost():
        return 'NewsPost';
      case _i8.ClubService():
        return 'ClubService';
      case _i9.ClubSession():
        return 'ClubSession';
      case _i10.AppSetting():
        return 'AppSetting';
      case _i11.UserRole():
        return 'UserRole';
      case _i12.UserGender():
        return 'UserGender';
      case _i13.UserProfile():
        return 'UserProfile';
    }
    className = _i14.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'dartway_serverpod_core.$className';
    }
    className = _i15.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'dartway_push.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'BookingStatus') {
      return deserialize<_i2.BookingStatus>(data['data']);
    }
    if (dataClassName == 'SessionBooking') {
      return deserialize<_i3.SessionBooking>(data['data']);
    }
    if (dataClassName == 'SessionReview') {
      return deserialize<_i4.SessionReview>(data['data']);
    }
    if (dataClassName == 'ChatChannel') {
      return deserialize<_i5.ChatChannel>(data['data']);
    }
    if (dataClassName == 'ChatMessage') {
      return deserialize<_i6.ChatMessage>(data['data']);
    }
    if (dataClassName == 'NewsPost') {
      return deserialize<_i7.NewsPost>(data['data']);
    }
    if (dataClassName == 'ClubService') {
      return deserialize<_i8.ClubService>(data['data']);
    }
    if (dataClassName == 'ClubSession') {
      return deserialize<_i9.ClubSession>(data['data']);
    }
    if (dataClassName == 'AppSetting') {
      return deserialize<_i10.AppSetting>(data['data']);
    }
    if (dataClassName == 'UserRole') {
      return deserialize<_i11.UserRole>(data['data']);
    }
    if (dataClassName == 'UserGender') {
      return deserialize<_i12.UserGender>(data['data']);
    }
    if (dataClassName == 'UserProfile') {
      return deserialize<_i13.UserProfile>(data['data']);
    }
    if (dataClassName.startsWith('dartway_serverpod_core.')) {
      data['className'] = dataClassName.substring(23);
      return _i14.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('dartway_push.')) {
      data['className'] = dataClassName.substring(13);
      return _i15.Protocol().deserializeByClassName(data);
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
      return _i14.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i15.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
