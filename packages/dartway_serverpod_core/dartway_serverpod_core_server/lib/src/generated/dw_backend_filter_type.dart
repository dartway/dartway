/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

enum DwBackendFilterType implements _i1.SerializableModel {
  equals,
  greaterThan,
  greaterThanOrEquals,
  lessThan,
  lessThanOrEquals,
  like,
  ilike,
  inSet,
  and,
  or;

  static DwBackendFilterType fromJson(String name) {
    switch (name) {
      case 'equals':
        return DwBackendFilterType.equals;
      case 'greaterThan':
        return DwBackendFilterType.greaterThan;
      case 'greaterThanOrEquals':
        return DwBackendFilterType.greaterThanOrEquals;
      case 'lessThan':
        return DwBackendFilterType.lessThan;
      case 'lessThanOrEquals':
        return DwBackendFilterType.lessThanOrEquals;
      case 'like':
        return DwBackendFilterType.like;
      case 'ilike':
        return DwBackendFilterType.ilike;
      case 'inSet':
        return DwBackendFilterType.inSet;
      case 'and':
        return DwBackendFilterType.and;
      case 'or':
        return DwBackendFilterType.or;
      default:
        throw ArgumentError(
            'Value "$name" cannot be converted to "DwBackendFilterType"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
