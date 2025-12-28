import 'package:serverpod/serverpod.dart';

abstract class DwDtoConfig<DTO extends SerializableModel> {
  String get className => DTO.toString();

  const DwDtoConfig();
}
