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
      children: jsonSerialization['children'] == null
          ? null
          : (jsonSerialization['children'] as List)
              .map((e) => DwBackendFilter.fromJson(e))
              .toList() as dynamic,
      negate: jsonSerialization['negate'] as bool,
      // child: jsonSerialization['child'] == null
      //     ? null
      //     : NitBackendFilter.fromJson(
      //         jsonSerialization['child'],
      //       ),
    );
  }

  bool filterUpdate(
    Map<String, dynamic> jsonSerialization, {
    bool outerNegate = false,
  }) {
    bool shouldNegate = negate != outerNegate;

    if (type == DwBackendFilterType.and || type == DwBackendFilterType.or) {
      if (children == null || children!.isEmpty) {
        return true; // или другая логика для пустых групп
      }

      // Собираем детей, если нужно - с отрицанием
      final expressions = children!.map(
        (child) => child.filterUpdate(
          jsonSerialization,
          outerNegate: shouldNegate,
        ),
      );

      // Используем OR если фильтр такого типа или если это отрицание AND
      return expressions.reduce((a, b) =>
          shouldNegate != (type == DwBackendFilterType.or) ? a || b : a && b);
    }

    return _valueExpression(
      jsonSerialization,
      negate: shouldNegate,
    );
  }

  bool _isType<T1, T2>(Type t) => t == T1 || t == T2;

  bool _isNullableType(Type t) => _isType<T, T?>(t);

  bool _valueExpression(
    Map<String, dynamic> jsonSerialization, {
    bool negate = false,
  }) {
    // print(T.toString());
    if (T == dynamic) {
      throw Exception(
        'NitBackendFilter<$T>: тип не определён! '
        'Создайте фильтр с явным generic, например NitBackendFilter<int>().',
      );
    }
    final modelValue = DwCoreServerpodClient.protocol
        .deserialize<T?>(jsonSerialization['data'][fieldName]);

    if (type == DwBackendFilterType.equals) {
      return negate != (modelValue == fieldValue);
    }

    if (_isNullableType(int)) {
      return negate !=
          switch (type) {
            DwBackendFilterType.greaterThan => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as int) > (fieldValue as int))),
            DwBackendFilterType.greaterThanOrEquals => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as int) >= (fieldValue as int))),
            DwBackendFilterType.lessThan => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as int) < (fieldValue as int))),
            DwBackendFilterType.lessThanOrEquals => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as int) <= (fieldValue as int))),
            _ => throw Exception('Unsupported filter type'),
          };
    } else if (_isNullableType(double)) {
      return negate !=
          switch (type) {
            DwBackendFilterType.greaterThan => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as double) > (fieldValue as double))),
            DwBackendFilterType.greaterThanOrEquals => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as double) >= (fieldValue as double))),
            DwBackendFilterType.lessThan => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as double) < (fieldValue as double))),
            DwBackendFilterType.lessThanOrEquals => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as double) <= (fieldValue as double))),
            _ => throw Exception('Unsupported filter type'),
          };
    } else if (_isNullableType(DateTime)) {
      return negate !=
          switch (type) {
            DwBackendFilterType.greaterThan => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as DateTime)
                        .isAfter((fieldValue as DateTime)))),
            DwBackendFilterType.greaterThanOrEquals => fieldValue == null ||
                (modelValue != null &&
                    !(modelValue as DateTime)
                        .isBefore((fieldValue as DateTime))),
            DwBackendFilterType.lessThan => fieldValue == null ||
                (modelValue != null &&
                    ((modelValue as DateTime)
                        .isBefore((fieldValue as DateTime)))),
            DwBackendFilterType.lessThanOrEquals => fieldValue == null ||
                (modelValue != null &&
                    !(modelValue as DateTime)
                        .isAfter((fieldValue as DateTime))),
            _ => throw Exception('Unsupported filter type'),
          };
    } else if (_isNullableType(String)) {
      return negate !=
          switch (type) {
            DwBackendFilterType.ilike => fieldValue == null ||
                (modelValue != null &&
                    _ilikeMatch(modelValue as String, fieldValue as String)),
            _ => throw Exception('Unsupported filter type'),
          };
    }

    throw Exception('Unsupported filter type');
  }

  bool _ilikeMatch(String value, String pattern) {
    // Экранируем спецсимволы в RegExp, кроме % и _
    String escaped = RegExp.escape(pattern)
        .replaceAll('%', '<<<PERCENT>>>') // временные метки
        .replaceAll('_', '<<<UNDERSCORE>>>');

    // Преобразуем % и _ в шаблоны RegExp
    String regexPattern = escaped
        .replaceAll('<<<PERCENT>>>', '.*') // % → .*
        .replaceAll('<<<UNDERSCORE>>>', '.'); // _ → .

    // Добавляем начало и конец строки для точного совпадения
    RegExp regex =
        RegExp('^$regexPattern\$', caseSensitive: false, dotAll: true);

    return regex.hasMatch(value);
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
