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
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    as _i3;
import 'booking/enums/booking_status.dart' as _i4;
import 'booking/session_booking.dart' as _i5;
import 'booking/session_review.dart' as _i6;
import 'chat/chat_channel.dart' as _i7;
import 'chat/chat_message.dart' as _i8;
import 'news/news_post.dart' as _i9;
import 'schedule/club_service.dart' as _i10;
import 'schedule/club_session.dart' as _i11;
import 'settings/app_setting.dart' as _i12;
import 'user_profile/enums/user_role.dart' as _i13;
import 'user_profile/user_gender.dart' as _i14;
import 'user_profile/user_profile.dart' as _i15;
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

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'app_setting',
      dartName: 'AppSetting',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'app_setting_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'settingKey',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'settingValue',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'app_setting_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'app_setting_key_unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'settingKey',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'chat_channel',
      dartName: 'ChatChannel',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'chat_channel_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'title',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'chat_channel_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'chat_message',
      dartName: 'ChatMessage',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'chat_message_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'channelId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'authorProfileId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'messageText',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'chat_message_fk_0',
          columns: ['channelId'],
          referenceTable: 'chat_channel',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'chat_message_fk_1',
          columns: ['authorProfileId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'chat_message_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'club_service',
      dartName: 'ClubService',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'club_service_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'title',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'description',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'durationMinutes',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'price',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'imageUrl',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'club_service_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'club_session',
      dartName: 'ClubSession',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'club_session_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'serviceId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'coachProfileId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'startsAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'capacity',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'club_session_fk_0',
          columns: ['serviceId'],
          referenceTable: 'club_service',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'club_session_fk_1',
          columns: ['coachProfileId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'club_session_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'news_post',
      dartName: 'NewsPost',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'news_post_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'authorProfileId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'title',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'text',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'news_post_fk_0',
          columns: ['authorProfileId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'news_post_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'session_booking',
      dartName: 'SessionBooking',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'session_booking_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'clubSessionId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'clientProfileId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:BookingStatus',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'session_booking_fk_0',
          columns: ['clubSessionId'],
          referenceTable: 'club_session',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'session_booking_fk_1',
          columns: ['clientProfileId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'session_booking_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'session_review',
      dartName: 'SessionReview',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'session_review_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'bookingId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'rating',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'reviewText',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'session_review_fk_0',
          columns: ['bookingId'],
          referenceTable: 'session_booking',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'session_review_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'user_profile',
      dartName: 'UserProfile',
      schema: 'public',
      module: 'dartway_example',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'user_profile_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'userIdentifier',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'phone',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'agreedForMarketingCommunications',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i2.ColumnDefinition(
          name: 'conditionsAcceptedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'firstName',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'lastName',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'imageUrl',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'gender',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:UserGender?',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:UserRole',
          columnDefault: '\'client\'::text',
        ),
        _i2.ColumnDefinition(
          name: 'testVerificationCode',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'user_profile_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    ..._i3.Protocol.targetTableDefinitions,
    ..._i2.Protocol.targetTableDefinitions,
  ];

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

    if (t == _i4.BookingStatus) {
      return _i4.BookingStatus.fromJson(data) as T;
    }
    if (t == _i5.SessionBooking) {
      return _i5.SessionBooking.fromJson(data) as T;
    }
    if (t == _i6.SessionReview) {
      return _i6.SessionReview.fromJson(data) as T;
    }
    if (t == _i7.ChatChannel) {
      return _i7.ChatChannel.fromJson(data) as T;
    }
    if (t == _i8.ChatMessage) {
      return _i8.ChatMessage.fromJson(data) as T;
    }
    if (t == _i9.NewsPost) {
      return _i9.NewsPost.fromJson(data) as T;
    }
    if (t == _i10.ClubService) {
      return _i10.ClubService.fromJson(data) as T;
    }
    if (t == _i11.ClubSession) {
      return _i11.ClubSession.fromJson(data) as T;
    }
    if (t == _i12.AppSetting) {
      return _i12.AppSetting.fromJson(data) as T;
    }
    if (t == _i13.UserRole) {
      return _i13.UserRole.fromJson(data) as T;
    }
    if (t == _i14.UserGender) {
      return _i14.UserGender.fromJson(data) as T;
    }
    if (t == _i15.UserProfile) {
      return _i15.UserProfile.fromJson(data) as T;
    }
    if (t == _i1.getType<_i4.BookingStatus?>()) {
      return (data != null ? _i4.BookingStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.SessionBooking?>()) {
      return (data != null ? _i5.SessionBooking.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.SessionReview?>()) {
      return (data != null ? _i6.SessionReview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.ChatChannel?>()) {
      return (data != null ? _i7.ChatChannel.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.ChatMessage?>()) {
      return (data != null ? _i8.ChatMessage.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.NewsPost?>()) {
      return (data != null ? _i9.NewsPost.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.ClubService?>()) {
      return (data != null ? _i10.ClubService.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.ClubSession?>()) {
      return (data != null ? _i11.ClubSession.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.AppSetting?>()) {
      return (data != null ? _i12.AppSetting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.UserRole?>()) {
      return (data != null ? _i13.UserRole.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.UserGender?>()) {
      return (data != null ? _i14.UserGender.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.UserProfile?>()) {
      return (data != null ? _i15.UserProfile.fromJson(data) : null) as T;
    }
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i4.BookingStatus => 'BookingStatus',
      _i5.SessionBooking => 'SessionBooking',
      _i6.SessionReview => 'SessionReview',
      _i7.ChatChannel => 'ChatChannel',
      _i8.ChatMessage => 'ChatMessage',
      _i9.NewsPost => 'NewsPost',
      _i10.ClubService => 'ClubService',
      _i11.ClubSession => 'ClubSession',
      _i12.AppSetting => 'AppSetting',
      _i13.UserRole => 'UserRole',
      _i14.UserGender => 'UserGender',
      _i15.UserProfile => 'UserProfile',
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
      case _i4.BookingStatus():
        return 'BookingStatus';
      case _i5.SessionBooking():
        return 'SessionBooking';
      case _i6.SessionReview():
        return 'SessionReview';
      case _i7.ChatChannel():
        return 'ChatChannel';
      case _i8.ChatMessage():
        return 'ChatMessage';
      case _i9.NewsPost():
        return 'NewsPost';
      case _i10.ClubService():
        return 'ClubService';
      case _i11.ClubSession():
        return 'ClubSession';
      case _i12.AppSetting():
        return 'AppSetting';
      case _i13.UserRole():
        return 'UserRole';
      case _i14.UserGender():
        return 'UserGender';
      case _i15.UserProfile():
        return 'UserProfile';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
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
    if (dataClassName == 'BookingStatus') {
      return deserialize<_i4.BookingStatus>(data['data']);
    }
    if (dataClassName == 'SessionBooking') {
      return deserialize<_i5.SessionBooking>(data['data']);
    }
    if (dataClassName == 'SessionReview') {
      return deserialize<_i6.SessionReview>(data['data']);
    }
    if (dataClassName == 'ChatChannel') {
      return deserialize<_i7.ChatChannel>(data['data']);
    }
    if (dataClassName == 'ChatMessage') {
      return deserialize<_i8.ChatMessage>(data['data']);
    }
    if (dataClassName == 'NewsPost') {
      return deserialize<_i9.NewsPost>(data['data']);
    }
    if (dataClassName == 'ClubService') {
      return deserialize<_i10.ClubService>(data['data']);
    }
    if (dataClassName == 'ClubSession') {
      return deserialize<_i11.ClubSession>(data['data']);
    }
    if (dataClassName == 'AppSetting') {
      return deserialize<_i12.AppSetting>(data['data']);
    }
    if (dataClassName == 'UserRole') {
      return deserialize<_i13.UserRole>(data['data']);
    }
    if (dataClassName == 'UserGender') {
      return deserialize<_i14.UserGender>(data['data']);
    }
    if (dataClassName == 'UserProfile') {
      return deserialize<_i15.UserProfile>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('dartway_serverpod_core.')) {
      data['className'] = dataClassName.substring(23);
      return _i3.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i3.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i5.SessionBooking:
        return _i5.SessionBooking.t;
      case _i6.SessionReview:
        return _i6.SessionReview.t;
      case _i7.ChatChannel:
        return _i7.ChatChannel.t;
      case _i8.ChatMessage:
        return _i8.ChatMessage.t;
      case _i9.NewsPost:
        return _i9.NewsPost.t;
      case _i10.ClubService:
        return _i10.ClubService.t;
      case _i11.ClubSession:
        return _i11.ClubSession.t;
      case _i12.AppSetting:
        return _i12.AppSetting.t;
      case _i15.UserProfile:
        return _i15.UserProfile.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'dartway_example';

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
      return _i3.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
