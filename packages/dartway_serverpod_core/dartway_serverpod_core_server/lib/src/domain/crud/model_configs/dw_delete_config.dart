import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwDeleteConfig<T extends TableRow> {
  const DwDeleteConfig({this.allowDelete, this.afterDelete});

  final Future<bool> Function(Session session, T model)? allowDelete;
  final Future<List<TableRow>> Function(Session session, T model)? afterDelete;

  Future<DwApiResponse<bool>> delete(Session session, int modelId) async {
    final T? model = await session.db.findById<T>(modelId);

    if (model == null) {
      return DwApiResponse(
        isOk: true,
        value: true,
        warning: 'Model not found, possibly deleted earlier',
      );
    }

    if (allowDelete == null) {
      return DwApiResponse.notConfigured(source: 'delete $T');
    }

    if (true != await allowDelete?.call(session, model)) {
      return DwApiResponse.forbidden();
    }

    try {
      await session.db.deleteRow(model);
    } on DatabaseException {
      return DwApiResponse(
        isOk: false,
        value: false,
        error: 'Cannot delete model because other entities reference it',
      );
    }

    return DwApiResponse(
      isOk: true,
      value: true,
      updatedModels: [
        DwModelWrapper.deleted(object: model),
        if (afterDelete != null)
          ...(await afterDelete!(
            session,
            model,
          )).map((e) => DwModelWrapper(object: e)),
      ],
    );
  }
}
