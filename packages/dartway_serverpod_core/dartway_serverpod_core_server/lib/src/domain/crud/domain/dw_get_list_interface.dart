import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

abstract class DwGetListInterface<ModelOrDto extends SerializableModel> {
  /// Whether an unauthenticated caller may read this list. Declared here so
  /// the endpoint can ask a model list and a DTO list the same question.
  bool get allowAnonymous;

  Future<DwApiResponse<List<DwModelWrapper>>> getModelList(
    Session session, {
    Expression? whereClause,
    List<Order>? orderByList,
    int? limit,
    int? offset,
  });
}
