import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/api/dw_order_by.dart';
import '../domain/crud/domain/dw_get_list_interface.dart';
import '../private/dw_channel_stream.dart';
import '../private/dw_singleton.dart';

class DwCrudEndpoint extends Endpoint {
  final _deepEquality = const DeepCollectionEquality();

  DwApiResponse<T> returnError<T>(
    String errorMessage, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    dw.alerts.reportError(
      errorMessage,
      exception: exception,
      stackTrace: StackTrace.current,
    );
    return DwApiResponse(isOk: false, value: null, error: errorMessage);
  }

  Stream<SerializableModel> subscribeOnUpdates(
    Session session, {
    required String channel,
  }) {
    session.log('subscribeOnUpdates for $channel', level: LogLevel.debug);

    // The channel arrives as a bare string chosen by the client, so this guard
    // is the only thing standing between a guessed name and someone else's
    // updates. See [DwChannelConfig] for why authentication alone would not
    // have done it: every channel name in practice is a number away from
    // another user's.
    return guardedChannelStream<SerializableModel>(
      session,
      channel,
      canListen: dw.canListenTo,
    );
  }

  /// Rejects an unauthenticated caller unless the resolved config opted in.
  ///
  /// The gate lives here, per config, rather than on the endpoint: Serverpod's
  /// `requireLogin` is all-or-nothing for a whole endpoint, and this one CRUD
  /// endpoint serves every model — a public catalog and a private order list
  /// share it. Checked before the config runs, so an unauthenticated caller
  /// never reaches the database.
  Future<bool> _isCallerAllowed(Session session, bool allowAnonymous) async =>
      allowAnonymous || session.signedInUserProfileId != null;

  Future<DwApiResponse<DwModelWrapper>> getOne(
    Session session, {
    required String className,
    required DwBackendFilter filter,
    String? apiGroup,
  }) async {
    try {
      final caller = dw.getCrudConfig(className, api: apiGroup);

      session.log(
        'getOne for $className with filter: ${filter.attributeMap}',
        level: LogLevel.debug,
      );

      if (caller?.getModelConfigs == null || caller!.getModelConfigs!.isEmpty) {
        return DwApiResponse.notConfigured(source: 'getOne for $className');
      }

      final config = caller.getModelConfigs!.firstWhereOrNull(
        (e) => _deepEquality.equals(
          e.filterPrototype.attributeMap,
          filter.attributeMap,
        ),
      );

      if (config == null) {
        return DwApiResponse.notConfigured(source: 'getOne for $className');
      }

      if (!await _isCallerAllowed(session, config.allowAnonymous)) {
        return DwApiResponse.notAuthenticated(source: 'getOne for $className');
      }

      return await config.call(session, caller.table, filter);
    } catch (ex) {
      dw.alerts.reportError(ex.toString(), stackTrace: StackTrace.current);

      return DwApiResponse(
        isOk: false,
        value: null,
        error:
            'Unexpected error while handling the getOne request '
            'for $className',
      );
    }
  }

  Future<DwApiResponse<int>> getCount(
    Session session, {
    required String className,
    DwBackendFilter? filter,
    String? apiGroup,
  }) async {
    final caller = dw.getCrudConfig(className, api: apiGroup);

    session.log(
      'getCount for $className with filter: $filter',
      level: LogLevel.debug,
    );

    if (caller?.getListConfig == null) {
      return DwApiResponse.notConfigured(source: 'getCount for $className');
    }

    if (!await _isCallerAllowed(
      session,
      caller!.getListConfig!.allowAnonymous,
    )) {
      return DwApiResponse.notAuthenticated(source: 'getCount for $className');
    }

    return await caller.getListConfig!.getCount(
      session,
      whereClause: filter?.prepareWhere(caller.table),
    );
  }

  Future<DwApiResponse<List<DwModelWrapper>>> getAll(
    Session session, {
    required String className,
    DwBackendFilter? filter,
    List<DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroup,
  }) async {
    final crudConfig = dw.getCrudConfig(className, api: apiGroup);

    DwGetListInterface? caller = crudConfig?.getListConfig;

    if (caller == null) {
      final dtoConfig = dw.getDtoConfig(className, api: apiGroup);
      if (dtoConfig is DwDtoGetListConfig) {
        caller = dtoConfig;
      }
    }

    if (caller == null) {
      return DwApiResponse.notConfigured(source: 'getAll for $className');
    }

    if (!await _isCallerAllowed(session, caller.allowAnonymous)) {
      return DwApiResponse.notAuthenticated(source: 'getAll for $className');
    }

    final table = caller is DwDtoGetListConfig
        ? caller.queryTable
        : crudConfig!.table;

    return await caller.getModelList(
      session,
      whereClause: filter?.prepareWhere(table),
      orderByList: orderByList?.map((e) => e.prepareOrderBy(table)).toList(),
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
        final caller = dw.getDtoConfig(className, api: apiGroup);

        if (caller == null || caller is! DwDtoActionConfig) {
          return DwApiResponse.notConfigured(source: 'saveModel $className');
        }
        if (!await _isCallerAllowed(session, caller.allowAnonymous)) {
          return DwApiResponse.notAuthenticated(source: 'saveModel $className');
        }
        return await caller.save(session, model);
      } else {
        final caller = dw.getCrudConfig(className, api: apiGroup)?.saveConfig;

        if (caller == null) {
          return DwApiResponse.notConfigured(source: 'saveModel $className');
        }
        if (!await _isCallerAllowed(session, caller.allowAnonymous)) {
          return DwApiResponse.notAuthenticated(source: 'saveModel $className');
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

  Future<DwApiResponse<bool>> delete(
    Session session, {
    required String className,
    required int modelId,
    String? apiGroup,
  }) async {
    try {
      final caller = dw.getCrudConfig(className, api: apiGroup)?.deleteConfig;

      if (caller == null) {
        return DwApiResponse.notConfigured(source: 'delete $className');
      }

      if (!await _isCallerAllowed(session, caller.allowAnonymous)) {
        return DwApiResponse.notAuthenticated(source: 'delete $className');
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
