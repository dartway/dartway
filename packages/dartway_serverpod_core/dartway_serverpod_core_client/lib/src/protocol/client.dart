/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:dartway_serverpod_core_client/src/domain/api/dw_api_response.dart'
    as _i3;
import 'package:dartway_serverpod_core_client/src/domain/api/dw_model_wrapper.dart'
    as _i4;
import 'package:dartway_serverpod_core_client/src/domain/api/dw_backend_filter.dart'
    as _i5;
import 'package:dartway_serverpod_core_client/src/domain/api/dw_order_by.dart'
    as _i6;
import 'package:dartway_serverpod_core_client/src/protocol/cloud_files/dw_upload_ticket.dart'
    as _i7;
import 'package:dartway_serverpod_core_client/src/protocol/cloud_files/dw_cloud_file.dart'
    as _i8;

/// {@category Endpoint}
class EndpointDwCrud extends _i1.EndpointRef {
  EndpointDwCrud(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'dartway_serverpod_core.dwCrud';

  _i2.Stream<_i1.SerializableModel> subscribeOnUpdates({
    required String channel,
  }) =>
      caller.callStreamingServerEndpoint<
        _i2.Stream<_i1.SerializableModel>,
        _i1.SerializableModel
      >(
        'dartway_serverpod_core.dwCrud',
        'subscribeOnUpdates',
        {'channel': channel},
        {},
      );

  _i2.Future<_i3.DwApiResponse<_i4.DwModelWrapper>> getOne({
    required String className,
    required _i5.DwBackendFilter filter,
    String? apiGroup,
  }) => caller.callServerEndpoint<_i3.DwApiResponse<_i4.DwModelWrapper>>(
    'dartway_serverpod_core.dwCrud',
    'getOne',
    {
      'className': className,
      'filter': filter,
      'apiGroup': apiGroup,
    },
  );

  _i2.Future<_i3.DwApiResponse<int>> getCount({
    required String className,
    _i5.DwBackendFilter? filter,
    String? apiGroup,
  }) => caller.callServerEndpoint<_i3.DwApiResponse<int>>(
    'dartway_serverpod_core.dwCrud',
    'getCount',
    {
      'className': className,
      'filter': filter,
      'apiGroup': apiGroup,
    },
  );

  _i2.Future<_i3.DwApiResponse<List<_i4.DwModelWrapper>>> getAll({
    required String className,
    _i5.DwBackendFilter? filter,
    List<_i6.DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroup,
  }) => caller.callServerEndpoint<_i3.DwApiResponse<List<_i4.DwModelWrapper>>>(
    'dartway_serverpod_core.dwCrud',
    'getAll',
    {
      'className': className,
      'filter': filter,
      'orderByList': orderByList,
      'limit': limit,
      'offset': offset,
      'apiGroup': apiGroup,
    },
  );

  _i2.Future<_i3.DwApiResponse<_i4.DwModelWrapper>> saveModel({
    required _i4.DwModelWrapper wrappedModel,
    String? apiGroup,
  }) => caller.callServerEndpoint<_i3.DwApiResponse<_i4.DwModelWrapper>>(
    'dartway_serverpod_core.dwCrud',
    'saveModel',
    {
      'wrappedModel': wrappedModel,
      'apiGroup': apiGroup,
    },
  );

  _i2.Future<_i3.DwApiResponse<bool>> delete({
    required String className,
    required int modelId,
    String? apiGroup,
  }) => caller.callServerEndpoint<_i3.DwApiResponse<bool>>(
    'dartway_serverpod_core.dwCrud',
    'delete',
    {
      'className': className,
      'modelId': modelId,
      'apiGroup': apiGroup,
    },
  );
}

/// Uploads, in two steps that the server owns both ends of.
///
/// The endpoint used to take a key from the caller and sign an upload for
/// exactly it, which made two things possible for any signed-in user who knew
/// somebody else's key: overwriting the object behind it, and — through
/// `verifyUpload` alone, with no upload at all — being recorded as its owner.
/// Neither left a trace: object storage reports an overwrite on neither side,
/// and the only surviving evidence was a second row for one path.
///
/// So the caller no longer names anything it could collide with. It offers a
/// folder and may suggest a file name; the server builds the key, records it,
/// and afterwards accepts only the reservation it handed out.
/// {@category Endpoint}
class EndpointDwUpload extends _i1.EndpointRef {
  EndpointDwUpload(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'dartway_serverpod_core.dwUpload';

  /// Reserves a key for the caller and signs an upload for exactly that key.
  ///
  /// [folder] is where in the bucket the object belongs — `avatars`,
  /// `chat/rooms` — and it is a layout hint, sanitised rather than trusted.
  /// [fileName] is a suggestion for the readable part of the key, and it is
  /// what the object will download as. [fileExtension] describes the bytes
  /// being sent, which is not always the extension of the file the user picked:
  /// the client converts most images to JPEG on the way out, and the recorded
  /// mime type is read off this key.
  _i2.Future<_i7.DwUploadTicket?> getUploadDescription({
    String? folder,
    required String fileExtension,
    String? fileName,
  }) => caller.callServerEndpoint<_i7.DwUploadTicket?>(
    'dartway_serverpod_core.dwUpload',
    'getUploadDescription',
    {
      'folder': folder,
      'fileExtension': fileExtension,
      'fileName': fileName,
    },
  );

  /// Confirms the bytes for a reservation this server issued to this caller.
  ///
  /// It takes the reserved row rather than an object path, so a caller has
  /// nothing to name but its own reservation. Answers `null` when the
  /// reservation is unknown, belongs to somebody else, or holds no bytes yet —
  /// the three cases a caller must not be able to tell apart.
  _i2.Future<_i8.DwCloudFile?> verifyUpload({required int fileId}) =>
      caller.callServerEndpoint<_i8.DwCloudFile?>(
        'dartway_serverpod_core.dwUpload',
        'verifyUpload',
        {'fileId': fileId},
      );
}

class Caller extends _i1.ModuleEndpointCaller {
  Caller(_i1.ServerpodClientShared client) : super(client) {
    dwCrud = EndpointDwCrud(this);
    dwUpload = EndpointDwUpload(this);
  }

  late final EndpointDwCrud dwCrud;

  late final EndpointDwUpload dwUpload;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'dartway_serverpod_core.dwCrud': dwCrud,
    'dartway_serverpod_core.dwUpload': dwUpload,
  };
}
