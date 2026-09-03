import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import 'dw_server_transport.dart';

/// [DwServerTransport] over the generated Serverpod client — the default, and
/// what every application runs.
///
/// It is the only place in the Flutter half that knows the generated `Caller`
/// exists. `DwCore` builds one from the `client` it is given, so an app writes
/// nothing here; a test that wants to watch a write reaches for
/// `DwRecordingServerTransport` instead of standing this one up on a fake
/// client.
final class DwServerpodTransport implements DwServerTransport {
  /// Wraps [client], resolving the DartWay core module registered on it.
  ///
  /// Throws when the module is absent — the client was generated without
  /// `dartway_serverpod_core` in its `modules`, and no CRUD call could ever
  /// have worked.
  DwServerpodTransport(this._client) : _caller = _resolveCaller(_client);

  final ServerpodClientShared _client;
  final Caller _caller;

  static Caller _resolveCaller(ServerpodClientShared client) {
    final caller = client.moduleLookup.values.whereType<Caller>().firstOrNull;
    if (caller == null) {
      throw StateError(
        'DartWay core module not found on the Serverpod client.\n'
        'Add dartway_serverpod_core to the modules of your client project '
        'and re-run `serverpod generate`.',
      );
    }
    return caller;
  }

  @override
  SerializationManager get serializationManager => _client.serializationManager;

  @override
  Future<DwApiResponse<DwModelWrapper>> getOne({
    required String className,
    required DwBackendFilter filter,
    String? apiGroup,
  }) => _caller.dwCrud.getOne(
    className: className,
    filter: filter,
    apiGroup: apiGroup,
  );

  @override
  Future<DwApiResponse<List<DwModelWrapper>>> getAll({
    required String className,
    DwBackendFilter? filter,
    List<DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroup,
  }) => _caller.dwCrud.getAll(
    className: className,
    filter: filter,
    orderByList: orderByList,
    limit: limit,
    offset: offset,
    apiGroup: apiGroup,
  );

  @override
  Future<DwApiResponse<int>> getCount({
    required String className,
    DwBackendFilter? filter,
    String? apiGroup,
  }) => _caller.dwCrud.getCount(
    className: className,
    filter: filter,
    apiGroup: apiGroup,
  );

  @override
  Future<DwApiResponse<DwModelWrapper>> saveModel({
    required DwModelWrapper wrappedModel,
    String? apiGroup,
  }) =>
      _caller.dwCrud.saveModel(wrappedModel: wrappedModel, apiGroup: apiGroup);

  @override
  Future<DwApiResponse<bool>> delete({
    required String className,
    required int modelId,
    String? apiGroup,
  }) => _caller.dwCrud.delete(
    className: className,
    modelId: modelId,
    apiGroup: apiGroup,
  );

  @override
  Stream<SerializableModel> subscribeOnUpdates({required String channel}) =>
      _caller.dwCrud.subscribeOnUpdates(channel: channel);

  @override
  Future<DwUploadTicket?> getUploadDescription({
    String? folder,
    required String fileExtension,
    String? fileName,
  }) => _caller.dwUpload.getUploadDescription(
    folder: folder,
    fileExtension: fileExtension,
    fileName: fileName,
  );

  @override
  Future<DwCloudFile?> verifyUpload({required int fileId}) =>
      _caller.dwUpload.verifyUpload(fileId: fileId);
}
