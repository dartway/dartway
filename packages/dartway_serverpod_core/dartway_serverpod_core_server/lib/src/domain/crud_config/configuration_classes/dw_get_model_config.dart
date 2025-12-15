import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwGetModelConfig<T extends TableRow> {
  const DwGetModelConfig({
    required this.filterPrototype,
    this.createIfMissing,
    this.include,
    this.additionalModelsFetchFunction,
  });

  final DwBackendFilter filterPrototype;
  final Include? include;

  final Future<T?> Function(Session session, DwBackendFilter filter)?
  createIfMissing;

  final Future<List<TableRow>> Function(Session session, T model)?
  additionalModelsFetchFunction;

  Future<T?> _getObject(
    Session session,
    Table table,
    DwBackendFilter filter,
  ) async {
    return await session.db.findFirstRow(
          where: filter.prepareWhere(table),
          include: include,
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
      updatedModels:
          result != null
              ? [
                DwModelWrapper(object: result),
                if (additionalModelsFetchFunction != null)
                  ...(await additionalModelsFetchFunction!(
                    session,
                    result,
                  )).map((e) => DwModelWrapper(object: e)),
              ]
              : null,
    );
  }
}
