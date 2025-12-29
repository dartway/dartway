import 'package:serverpod/serverpod.dart';

mixin DwCrudEntity<MappingClass extends SerializableModel> {
  String get className => MappingClass.toString();
}
