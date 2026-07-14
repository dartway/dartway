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

abstract class AppSetting implements _i1.SerializableModel {
  AppSetting._({
    this.id,
    required this.settingKey,
    required this.settingValue,
  });

  factory AppSetting({
    int? id,
    required String settingKey,
    required String settingValue,
  }) = _AppSettingImpl;

  factory AppSetting.fromJson(Map<String, dynamic> jsonSerialization) {
    return AppSetting(
      id: jsonSerialization['id'] as int?,
      settingKey: jsonSerialization['settingKey'] as String,
      settingValue: jsonSerialization['settingValue'] as String,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String settingKey;

  String settingValue;

  /// Returns a shallow copy of this [AppSetting]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AppSetting copyWith({
    int? id,
    String? settingKey,
    String? settingValue,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AppSetting',
      if (id != null) 'id': id,
      'settingKey': settingKey,
      'settingValue': settingValue,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AppSettingImpl extends AppSetting {
  _AppSettingImpl({
    int? id,
    required String settingKey,
    required String settingValue,
  }) : super._(
         id: id,
         settingKey: settingKey,
         settingValue: settingValue,
       );

  /// Returns a shallow copy of this [AppSetting]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AppSetting copyWith({
    Object? id = _Undefined,
    String? settingKey,
    String? settingValue,
  }) {
    return AppSetting(
      id: id is int? ? id : this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
    );
  }
}
