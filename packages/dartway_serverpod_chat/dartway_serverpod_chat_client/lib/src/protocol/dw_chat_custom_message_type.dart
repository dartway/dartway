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

abstract class DwChatCustomMessageType implements _i1.SerializableModel {
  DwChatCustomMessageType._({
    required this.type,
    this.additionalModelId,
  });

  factory DwChatCustomMessageType({
    required String type,
    int? additionalModelId,
  }) = _DwChatCustomMessageTypeImpl;

  factory DwChatCustomMessageType.fromJson(
      Map<String, dynamic> jsonSerialization) {
    return DwChatCustomMessageType(
      type: jsonSerialization['type'] as String,
      additionalModelId: jsonSerialization['additionalModelId'] as int?,
    );
  }

  String type;

  int? additionalModelId;

  /// Returns a shallow copy of this [DwChatCustomMessageType]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatCustomMessageType copyWith({
    String? type,
    int? additionalModelId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (additionalModelId != null) 'additionalModelId': additionalModelId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwChatCustomMessageTypeImpl extends DwChatCustomMessageType {
  _DwChatCustomMessageTypeImpl({
    required String type,
    int? additionalModelId,
  }) : super._(
          type: type,
          additionalModelId: additionalModelId,
        );

  /// Returns a shallow copy of this [DwChatCustomMessageType]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatCustomMessageType copyWith({
    String? type,
    Object? additionalModelId = _Undefined,
  }) {
    return DwChatCustomMessageType(
      type: type ?? this.type,
      additionalModelId: additionalModelId is int?
          ? additionalModelId
          : this.additionalModelId,
    );
  }
}
