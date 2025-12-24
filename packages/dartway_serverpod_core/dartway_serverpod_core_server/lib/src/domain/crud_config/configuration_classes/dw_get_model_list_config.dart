import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_get_config_interface.dart';

class DwGetListConfig<T extends TableRow> extends DwGetConfigInterface<T> {
  const DwGetListConfig({
    required super.accessFilter,
    super.include,
    // this.additionalModelsFetchFunction,
    super.defaultOrderByList,
  });

  Future<DwApiResponse<int>> getCount(
    Session session, {
    Expression? whereClause,
  }) async {
    final result = await session.db.count<T>(
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
    final resultItems = await session.db.find<T>(
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
