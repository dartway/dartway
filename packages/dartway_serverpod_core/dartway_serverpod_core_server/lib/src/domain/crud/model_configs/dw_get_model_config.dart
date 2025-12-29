import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/dw_get_interface.dart';

class DwGetModelConfig<T extends TableRow> extends DwGetConfigInterface<T> {
  const DwGetModelConfig({
    required super.accessFilter,
    required this.filterPrototype,
    this.createIfMissing,
    super.include,
    super.defaultOrderByList,
    // super.additionalModelsFetchFunction,
  });

  final DwBackendFilter filterPrototype;

  final Future<T?> Function(Session session, DwBackendFilter filter)?
      createIfMissing;

  Future<T?> _getObject(
    Session session,
    Table table,
    DwBackendFilter filter,
  ) async {
    return await session.db.findFirstRow(
          where: await getWhereExpression(
            session,
            whereClause: filter.prepareWhere(table),
          ),
          include: include,
          orderByList: defaultOrderByList,
        ) ??
        await createIfMissing?.call(session, filter);
  }

  Future<DwApiResponse<DwModelWrapper>> call(
    Session session,
    Table table,
    DwBackendFilter filter,
  ) async {
    final result = await _getObject(session, table, filter);
    return DwApiResponse<DwModelWrapper>(
      isOk: true,
      value: DwModelWrapper.wrap(result),
      updatedModels: result != null
          ? [
              DwModelWrapper(object: result),
              // if (additionalModelsFetchFunction != null)
              //   ...(await additionalModelsFetchFunction!(
              //     session,
              //     result,
              //   ))
              //       .map((e) => DwModelWrapper(object: e)),
            ]
          : null,
    );
  }
}
