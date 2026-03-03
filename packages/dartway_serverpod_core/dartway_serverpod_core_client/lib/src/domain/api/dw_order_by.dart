import 'package:serverpod_client/serverpod_client.dart';

class DwOrderBy implements SerializableModel {
  const DwOrderBy._({
    required this.fieldName,
    required this.orderDescending,
  });

  final String? fieldName;
  final bool orderDescending;

  DwOrderBy({
    required this.fieldName,
    required this.orderDescending,
  });

  factory DwOrderBy.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwOrderBy._(
      fieldName: jsonSerialization['fieldName'] as String?,
      orderDescending: jsonSerialization['orderDescending'] as bool,
    );
  }

  @override
  toJson() {
    return {
      'fieldName': fieldName,
      'orderDescending': orderDescending,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DwOrderBy &&
            (identical(other.fieldName, fieldName) ||
                other.fieldName == fieldName) &&
            (identical(other.orderDescending, orderDescending) ||
                other.orderDescending == orderDescending));
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        fieldName,
        orderDescending,
      );
}
