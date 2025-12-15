import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

class DwBackendFilter<T> implements SerializableModel {
  static final _listEquality = DeepCollectionEquality();

  static String getClassNameForObject(Object? object) {
    return DwCoreServerpodClient.protocol.getClassNameForObject(object) ??
        'unknown';
  }

  const DwBackendFilter._({
    required this.type,
    required this.fieldName,
    required this.fieldValue,
    required this.children,
    bool? negate,
  }) : negate = negate ?? false;

  final String? fieldName;
  final DwBackendFilterType type;
  final T? fieldValue;
  final List<DwBackendFilter>? children;
  final bool negate;

  const DwBackendFilter.and(this.children, {this.negate = false})
    : fieldName = null,
      type = DwBackendFilterType.and,
      fieldValue = null;

  const DwBackendFilter.or(this.children, {this.negate = false})
    : fieldName = null,
      type = DwBackendFilterType.or,
      fieldValue = null;

  const DwBackendFilter.value({
    required this.type,
    this.fieldName,
    required this.fieldValue,
    this.negate = false,
  }) : children = null;

  factory DwBackendFilter.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwBackendFilter._(
      type: DwBackendFilterType.fromJson((jsonSerialization['type'] as String)),
      fieldName: jsonSerialization['fieldName'] as String,
      fieldValue: jsonSerialization['fieldValue'] as T?,
      children:
          jsonSerialization['children'] == null
              ? null
              : (jsonSerialization['children'] as List)
                      .map((e) => DwBackendFilter.fromJson(e))
                      .toList()
                  as dynamic,
      negate: jsonSerialization['negate'] as bool,
      // child: jsonSerialization['child'] == null
      //     ? null
      //     : NitBackendFilter.fromJson(
      //         jsonSerialization['child'],
      //       ),
    );
  }

  @override
  toJson() {
    return {
      'type': type.toJson(),
      'valueClassName': getClassNameForObject(fieldValue),
      if (fieldName != null) 'fieldName': fieldName,
      if (fieldValue != null) 'fieldValue': fieldValue,
      if (children != null) 'children': [...children!.map((e) => e.toJson())],
      'negate': negate,
      // if (child != null) 'child': child!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DwBackendFilter &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.fieldName, fieldName) ||
                other.fieldName == fieldName) &&
            (identical(other.fieldValue, fieldValue) ||
                other.fieldValue == fieldValue) &&
            _listEquality.equals(other.children, children) &&
            (identical(other.negate, negate) || other.negate == negate));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    type,
    fieldName,
    fieldValue,
    _listEquality.hash(children),
    negate,
  );
}
