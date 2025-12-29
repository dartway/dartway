import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/dw_get_interface.dart';
import '../domain/dw_get_list_interface.dart';

class DwGetModelListConfig<Model extends TableRow>
    extends DwGetConfigInterface<Model> implements DwGetListInterface<Model> {
  const DwGetModelListConfig({
    required super.accessFilter,
    super.include,
    // this.additionalModelsFetchFunction,
    super.defaultOrderByList,
  });

  Future<DwApiResponse<int>> getCount(
    Session session, {
    Expression? whereClause,
  }) async {
    final result = await session.db.count<Model>(
      where: await getWhereExpression(session, whereClause: whereClause),
    );

    return DwApiResponse<int>(isOk: true, value: result);
  }

  Future<DwApiResponse<List<DwModelWrapper>>> getModelList(
    Session session, {
    Expression? whereClause,
    int? limit,
    int? offset,
  }) async {
    final resultItems = await session.db.find<Model>(
      where: await getWhereExpression(session, whereClause: whereClause),
      include: include,
      orderByList: defaultOrderByList,
      limit: limit,
      offset: offset,
    );

    return DwApiResponse<List<DwModelWrapper>>(
      isOk: true,
      value: resultItems.map((e) => DwModelWrapper(object: e)).toList(),
      updatedModels: null,
      //  [
      //   if (additionalModelsFetchFunction != null)
      //     ...(await additionalModelsFetchFunction!(session, resultItems)),
      // ].map((e) => DwModelWrapper(object: e)).toList(),
    );
  }
}
