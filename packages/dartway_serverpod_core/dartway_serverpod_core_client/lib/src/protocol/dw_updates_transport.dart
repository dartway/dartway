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
import '/src/domain/api/dw_model_wrapper.dart' as _i2;

abstract class DwUpdatesTransport implements _i1.SerializableModel {
  DwUpdatesTransport._({required this.wrappedModelUpdates});

  factory DwUpdatesTransport(
          {required List<_i2.DwModelWrapper> wrappedModelUpdates}) =
      _DwUpdatesTransportImpl;

  factory DwUpdatesTransport.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwUpdatesTransport(
        wrappedModelUpdates: (jsonSerialization['wrappedModelUpdates'] as List)
            .map((e) => _i2.DwModelWrapper.fromJson(e))
            .toList());
  }

  List<_i2.DwModelWrapper> wrappedModelUpdates;

  /// Returns a shallow copy of this [DwUpdatesTransport]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwUpdatesTransport copyWith({List<_i2.DwModelWrapper>? wrappedModelUpdates});
  @override
  Map<String, dynamic> toJson() {
    return {
      'wrappedModelUpdates':
          wrappedModelUpdates.toJson(valueToJson: (v) => v.toJson())
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DwUpdatesTransportImpl extends DwUpdatesTransport {
  _DwUpdatesTransportImpl(
      {required List<_i2.DwModelWrapper> wrappedModelUpdates})
      : super._(wrappedModelUpdates: wrappedModelUpdates);

  /// Returns a shallow copy of this [DwUpdatesTransport]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwUpdatesTransport copyWith({List<_i2.DwModelWrapper>? wrappedModelUpdates}) {
    return DwUpdatesTransport(
        wrappedModelUpdates: wrappedModelUpdates ??
            this.wrappedModelUpdates.map((e0) => e0.copyWith()).toList());
  }
}
