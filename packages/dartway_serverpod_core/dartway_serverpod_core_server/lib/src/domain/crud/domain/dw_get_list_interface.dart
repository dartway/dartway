import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

abstract class DwGetListInterface<ModelOrDto extends SerializableModel> {
  Future<DwApiResponse<List<DwModelWrapper>>> getModelList(
    Session session, {
    Expression? whereClause,
    int? limit,
    int? offset,
  });
}
