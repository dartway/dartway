import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/crud/domain/dw_get_list_interface.dart';

class DwCrudEndpoint extends Endpoint {
  final _deepEquality = const DeepCollectionEquality();

  DwApiResponse<T> returnError<T>(
    String errorMessage, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    DwCore.instance.alerts.reportError(
      errorMessage,
      exception: exception,
      stackTrace: StackTrace.current,
    );
    return DwApiResponse(isOk: false, value: null, error: errorMessage);
  }

  Stream<SerializableModel> subscribeOnUpdates(
    Session session, {
    required String channel,
  }) async* {
    print("subscribeOnUpdates for $channel");
    yield* session.messages.createStream<SerializableModel>(channel);
  }

  Future<DwApiResponse<DwModelWrapper>> getOne(
    Session session, {
    required String className,
    required DwBackendFilter filter,
    String? apiGroup,
  }) async {
    try {
      final caller = DwCore.instance.getCrudConfig(className, api: apiGroup);

      print(
        "Received getOneCustom request for $className with filter: ${filter.attributeMap}",
      );

      if (caller?.getModelConfigs == null || caller!.getModelConfigs!.isEmpty) {
        return DwApiResponse.notConfigured(source: 'получение $className');
      }

      final config = caller.getModelConfigs!.firstWhereOrNull(
        (e) => _deepEquality.equals(
          e.filterPrototype.attributeMap,
          filter.attributeMap,
        ),
      );

      if (config == null) {
        return DwApiResponse.notConfigured(source: 'получение $className');
      }

      return await config.call(session, caller.table, filter);
    } catch (ex) {
      DwCore.instance.alerts.reportError(
        ex.toString(),
        stackTrace: StackTrace.current,
      );

      return DwApiResponse(
        isOk: false,
        value: null,
        error:
            'Непредвиденная ошибка при обработке запроса на получение $className',
      );
    }
  }

  Future<DwApiResponse<int>> getCount(
    Session session, {
    required String className,
    DwBackendFilter? filter,
    String? apiGroup,
  }) async {
    final caller = DwCore.instance.getCrudConfig(className, api: apiGroup);

    print("CRUD: getCount for $className with filter: $filter");

    if (caller?.getListConfig == null) {
      return DwApiResponse.notConfigured(source: 'getCount for $className');
    }

    return await caller!.getListConfig!.getCount(
      session,
      whereClause: filter?.prepareWhere(caller.table),
    );
  }

  Future<DwApiResponse<List<DwModelWrapper>>> getAll(
    Session session, {
    required String className,
    DwBackendFilter? filter,
    int? limit,
    int? offset,
    String? apiGroup,
  }) async {
    final crudConfig = DwCore.instance.getCrudConfig(className, api: apiGroup);

    DwGetListInterface? caller = crudConfig?.getListConfig;

    if (caller == null) {
      final dtoConfig = DwCore.instance.getDtoConfig(className, api: apiGroup);
      if (dtoConfig is DwDtoGetListConfig) {
        caller = dtoConfig;
      }
    }

    if (caller == null) {
      return DwApiResponse.notConfigured(source: 'получение списка $className');
    }

    final table =
        caller is DwDtoGetListConfig ? caller.queryTable : crudConfig!.table;

    return await caller.getModelList(
      session,
      whereClause: filter?.prepareWhere(table),
      limit: limit,
      offset: offset,
    );
  }

  Future<DwApiResponse<DwModelWrapper>> saveModel(
    Session session, {
    required DwModelWrapper wrappedModel,
    String? apiGroup,
  }) async {
    try {
      final model = wrappedModel.object;
      final className = wrappedModel.dwMappingClassname;

      if (model is! TableRow) {
        // throw UnsupportedError(
        //   'Received item of unsupported type: ${model.runtimeType}. Only TableRow could be saved to database',
        // );
        final caller = DwCore.instance.getDtoConfig(className, api: apiGroup);

        if (caller == null || caller is! DwDtoSaveConfig) {
          return DwApiResponse.notConfigured(source: 'saveModel $className');
        }
        return await caller.save(session, model);
      } else {
        final caller =
            DwCore.instance.getCrudConfig(className, api: apiGroup)?.saveConfig;

        if (caller == null) {
          return DwApiResponse.notConfigured(source: 'saveModel $className');
        }
        return await caller.save(session, model);
      }
    } catch (ex, st) {
      return returnError(
        'Unexpected error during saveModel ${wrappedModel.dwMappingClassname}',
        exception: ex,
        stackTrace: st,
      );
    }
  }

  Stream<SerializableModel> saveModelStream(
    Session session, {
    required DwModelWrapper wrappedModel,
    required String channelName,
    String? apiGroup,
  }) async* {
    try {
      final model = wrappedModel.object;
      if (model is! TableRow) {
        throw UnsupportedError(
          'Received item of unsupported type: ${model.runtimeType}. Only TableRow could be saved to database',
        );
      }

      final className = wrappedModel.dwMappingClassname;
      final caller =
          DwCore.instance.getCrudConfig(className, api: apiGroup)?.saveConfig;

      if (caller == null) {
        throw Exception('notConfigured(source: saveModelStream $className');
      }

      final stream = session.messages.createStream<SerializableModel>(
        channelName,
      );

      () async {
        try {
          final res = await caller.save(session, model);

          await session.messages.postMessage(
            channelName,
            DwUpdatesTransport(
              wrappedModelUpdates: [
                if (res.value != null) res.value!,
                if (res.updatedModels != null) ...res.updatedModels!,
              ],
            ),
          );
        } catch (ex, st) {
          return returnError(
            'Unexpected error during saveModelStream for ${model.id == null ? 'new' : 'existing'} ${wrappedModel.dwMappingClassname} ${model.id != null ? 'with id ${model.id} ' : ''}',
            exception: ex,
            stackTrace: st,
          );
        }
      }(); // fire-and-forget

      await for (var message in stream) {
        yield message;
      }
    } catch (ex, st) {
      final id = wrappedModel.modelId;
      returnError(
        'Unexpected error during saveModelStream for ${id == null ? 'new' : 'existing'} ${wrappedModel.dwMappingClassname} ${id != null ? 'with id $id ' : ''}',
        exception: ex,
        stackTrace: st,
      );
    }
  }

  Future<DwApiResponse<bool>> delete(
    Session session, {
    required String className,
    required int modelId,
    String? apiGroup,
  }) async {
    try {
      final caller =
          DwCore.instance.getCrudConfig(className, api: apiGroup)?.deleteConfig;

      if (caller == null) {
        return DwApiResponse.notConfigured(source: 'delete $className');
      }

      return await caller.delete(session, modelId);
    } catch (ex, st) {
      return returnError(
        'Unexpected error during delete $className with id $modelId',
        exception: ex,
        stackTrace: st,
      );
    }
  }
}
