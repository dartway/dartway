import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwGetListConfig<T extends TableRow> {
  const DwGetListConfig({
    this.include,
    this.additionalModelsFetchFunction,
    this.defaultOrderByList,
  });

  final Include? include;
  final List<Order>? defaultOrderByList;

  final Future<List<TableRow>> Function(Session session, List<T> models)?
  additionalModelsFetchFunction;

  Future<DwApiResponse<int>> getCount(
    Session session, {
    Expression? whereClause,
  }) async {
    final result = await session.db.count<T>(where: whereClause);

    return DwApiResponse<int>(isOk: true, value: result);
  }

  Future<DwApiResponse<List<DwModelWrapper>>> getModelList(
    Session session, {
    Expression? whereClause,
    int? limit,
    int? offset,
  }) async {
    final resultItems = await session.db.find<T>(
      where: whereClause,
      include: include,
      orderByList: defaultOrderByList,
      limit: limit,
      offset: offset,
    );

    return DwApiResponse<List<DwModelWrapper>>(
      isOk: true,
      value: resultItems.map((e) => DwModelWrapper(object: e)).toList(),
      updatedModels:
          [
            if (additionalModelsFetchFunction != null)
              ...(await additionalModelsFetchFunction!(session, resultItems)),
          ].map((e) => DwModelWrapper(object: e)).toList(),
    );
  }
}
