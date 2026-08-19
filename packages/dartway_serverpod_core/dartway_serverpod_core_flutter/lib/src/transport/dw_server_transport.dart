import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

/// Every server operation `dw.repo` performs, and nothing else.
///
/// This is the whole dependency the client-side repository has on the server:
/// five CRUD calls, one realtime subscription, and the two-step upload
/// handshake. Everything an app reaches — the read providers, `saveModel`,
/// `deleteModel`, `DwFileUploadHandler` — ends here, so replacing this
/// replaces the wire without touching a line of feature code.
///
/// Two things follow from that, and both are the reason it exists as a type:
///
/// * **A test can observe a write.** The repository does not name the generated
///   Serverpod client any more, so a test hands `DwCore` a transport of its own
///   instead of subclassing `ServerpodClientShared` and decoding string-keyed
///   endpoint arguments. The core ships one for that —
///   `DwRecordingServerTransport` in
///   `package:dartway_serverpod_core_flutter/testing.dart`.
/// * **Serverpod is replaceable.** The default implementation,
///   `DwServerpodTransport`, is the only place in the Flutter half that knows
///   what a generated `Caller` is.
///
/// The local store is *not* an alternative to this. `dw.repo.localWrites` keeps
/// a write that failed on the connection; a write still always leaves by this
/// path first. See `DwRepoLocalWrites`.
///
/// Implementations are expected to be cheap to construct and to hold no state
/// the core owns — `DwCore` builds or receives exactly one and keeps it for its
/// lifetime.
abstract interface class DwServerTransport {
  /// How models are named and rebuilt on the wire this transport speaks.
  ///
  /// It belongs here because encoding *is* part of speaking to a server: the
  /// class name that travels with every wrapped model comes from this, and the
  /// core installs it globally ([DwCoreServerpodClient.protocol]) the moment
  /// the transport is known. A transport that answers calls but cannot name a
  /// model would let `DwModelWrapper.wrap` fail long after construction, on the
  /// first save.
  SerializationManager get serializationManager;

  // --- CRUD ------------------------------------------------------------------

  /// Reads the single [className] row matching [filter].
  Future<DwApiResponse<DwModelWrapper>> getOne({
    required String className,
    required DwBackendFilter filter,
    String? apiGroup,
  });

  /// Reads the [className] rows matching [filter], ordered and paginated.
  Future<DwApiResponse<List<DwModelWrapper>>> getAll({
    required String className,
    DwBackendFilter? filter,
    List<DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroup,
  });

  /// Counts the [className] rows matching [filter], server-side.
  Future<DwApiResponse<int>> getCount({
    required String className,
    DwBackendFilter? filter,
    String? apiGroup,
  });

  /// Creates or updates [wrappedModel]; answers with the persisted model.
  Future<DwApiResponse<DwModelWrapper>> saveModel({
    required DwModelWrapper wrappedModel,
    String? apiGroup,
  });

  /// Deletes row [modelId] of [className].
  Future<DwApiResponse<bool>> delete({
    required String className,
    required int modelId,
    String? apiGroup,
  });

  // --- Realtime --------------------------------------------------------------

  /// Opens the server-side update stream for [channel].
  ///
  /// One stream per channel; the connection is the streams, so subscribing is
  /// connecting and the last cancellation disconnects. Called by
  /// `DwSocketService`, never by an app directly.
  Stream<SerializableModel> subscribeOnUpdates({required String channel});

  // --- Uploads ---------------------------------------------------------------

  /// Asks the server for a one-shot upload description for [path], or `null`
  /// when it refuses the path.
  Future<String?> getUploadDescription({required String path});

  /// Confirms with the server that the bytes at [path] arrived, and answers
  /// with the stored file — `null` when the upload cannot be verified.
  Future<DwCloudFile?> verifyUpload({required String path});
}
