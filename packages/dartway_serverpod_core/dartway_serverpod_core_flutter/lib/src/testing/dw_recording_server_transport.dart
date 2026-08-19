import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import '../transport/dw_server_transport.dart';

/// One save that left through the transport.
class DwRecordedSave {
  const DwRecordedSave({required this.wrappedModel, required this.apiGroup});

  /// The model as the repository wrapped it for the wire.
  final DwModelWrapper wrappedModel;

  /// The model itself, unwrapped — what an assertion usually wants.
  SerializableModel get model => wrappedModel.model;

  final String? apiGroup;

  @override
  String toString() =>
      'DwRecordedSave(${wrappedModel.className}, apiGroup: $apiGroup)';
}

/// One delete that left through the transport.
class DwRecordedDelete {
  const DwRecordedDelete({
    required this.className,
    required this.modelId,
    required this.apiGroup,
  });

  final String className;
  final int modelId;
  final String? apiGroup;

  @override
  String toString() =>
      'DwRecordedDelete($className#$modelId, apiGroup: $apiGroup)';
}

/// One read that left through the transport.
///
/// [limit], [offset] and [orderByList] are `null` for a `getOne` and a
/// `getCount`, which have no such arguments.
class DwRecordedRead {
  const DwRecordedRead({
    required this.operation,
    required this.className,
    required this.filter,
    this.orderByList,
    this.limit,
    this.offset,
    required this.apiGroup,
  });

  /// `getOne`, `getAll` or `getCount`.
  final String operation;
  final String className;
  final DwBackendFilter? filter;
  final List<DwOrderBy>? orderByList;
  final int? limit;
  final int? offset;
  final String? apiGroup;

  @override
  String toString() =>
      'DwRecordedRead($operation $className, apiGroup: $apiGroup)';
}

/// Thrown when the code under test performed a server operation the test never
/// prepared an answer for.
///
/// It is a failure and not an empty answer on purpose: a read nobody prepared
/// is a test that does not know what its subject fetches, and an empty list
/// would hide that behind an empty-state widget that looks deliberate.
class DwUnpreparedServerCall extends Error {
  DwUnpreparedServerCall(this.operation, this.responder, this.details);

  /// The transport method that was called.
  final String operation;

  /// The field on [DwRecordingServerTransport] that would answer it.
  final String responder;

  /// What was asked for, so the message names the call and not just the method.
  final String details;

  @override
  String toString() =>
      'DwUnpreparedServerCall: the code under test called '
      '$operation($details), and the transport had no answer ready.\n'
      'Prepare one by setting `$responder` on the transport before the code '
      'runs — a read is never answered by default, because a test that does '
      'not know what its subject fetches is the thing being caught here.';
}

/// A [DwServerTransport] that answers reads from what the test prepared and
/// keeps every write that left, for a test to assert on afterwards.
///
/// Hand it to `DwCore` **instead of** a `client`, and nothing has to stand up a
/// Serverpod client to render a widget or watch it save:
///
/// ```dart
/// final transport = DwRecordingServerTransport(
///   classNames: {Task: 'Task'},
/// );
///
/// setUpAll(() {
///   DwCore<ServerpodClientShared, Task>(
///     config: const DwConfig(),
///     transport: transport,
///     dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
///     getUserId: (_) => null,
///   );
/// });
///
/// testWidgets('the button saves the task', (tester) async {
///   await tester.pumpWidget(/* the feature */);
///   await tester.tap(find.byIcon(Icons.check));
///   await tester.pumpAndSettle();
///
///   expect(transport.saves, hasLength(1));
///   expect((transport.saves.single.model as Task).isDone, isTrue);
/// });
/// ```
///
/// **Reads must be prepared, writes need not be.** A read nobody answered
/// throws [DwUnpreparedServerCall], because the test does not know what its
/// subject fetches. A save answers by echoing the model back and a delete by
/// succeeding, because there the assertion is about what *left*, and forcing a
/// canned response for it would be ceremony with nothing behind it. Override
/// either with [answerSave] / [answerDelete] when the response matters — an id
/// assigned on insert, a rejected write.
///
/// One instance per core, and [reset] between tests: the core keeps the
/// transport it was built with for its whole life, and `DwCore` can be built
/// only once per process.
class DwRecordingServerTransport implements DwServerTransport {
  /// **An application passes [serializationManager], and passes its own
  /// generated `Protocol()`** — the same object its Serverpod client carries.
  /// It already names every model of the project correctly, and it is the only
  /// thing that can: a generated model is an abstract class with a private
  /// implementation, so its `runtimeType` is `_NewsPostImpl` and never the name
  /// the wire uses. It is also what a test needs to read a model *back* — a
  /// local snapshot rebuilds its response from stored JSON.
  ///
  /// [classNames] is the shorthand for the other case, a test over models it
  /// invented itself, which the framework's own tests are full of: it maps each
  /// one to the name it travels under. Pass one or the other, not both. A model
  /// covered by neither is refused when it is first named, rather than sent
  /// under a name no server knows.
  DwRecordingServerTransport({
    Map<Type, String> classNames = const {},
    SerializationManager? serializationManager,
  }) : assert(
         serializationManager == null || classNames.isEmpty,
         'classNames is the shorthand for building a serializationManager; '
         'passing both means one of them is silently ignored.',
       ),
       serializationManager =
           serializationManager ?? _RecordingSerializationManager(classNames);

  @override
  final SerializationManager serializationManager;

  /// Every save that left, oldest first.
  final saves = <DwRecordedSave>[];

  /// Every delete that left, oldest first.
  final deletes = <DwRecordedDelete>[];

  /// Every read that left, oldest first — including the ones that then threw
  /// [DwUnpreparedServerCall], so a failing test can be told what was asked.
  final reads = <DwRecordedRead>[];

  /// Answers `getOne`. Unset means every `getOne` throws.
  Future<DwApiResponse<DwModelWrapper>> Function(DwRecordedRead read)?
  answerGetOne;

  /// Answers `getAll`. Unset means every `getAll` throws.
  Future<DwApiResponse<List<DwModelWrapper>>> Function(DwRecordedRead read)?
  answerGetAll;

  /// Answers `getCount`. Unset means every `getCount` throws.
  Future<DwApiResponse<int>> Function(DwRecordedRead read)? answerGetCount;

  /// Answers `saveModel`. Unset echoes the saved model back, as a server that
  /// accepted it unchanged would.
  Future<DwApiResponse<DwModelWrapper>> Function(DwRecordedSave save)?
  answerSave;

  /// Answers `delete`. Unset reports success.
  Future<DwApiResponse<bool>> Function(DwRecordedDelete delete)? answerDelete;

  /// Answers `subscribeOnUpdates`. Unset opens a stream that never emits and
  /// never ends.
  ///
  /// Silence rather than a throw, unlike the reads: a channel is opened by the
  /// framework when a subscribing widget mounts, not by the test, so failing
  /// here would break tests about something else entirely with a message about
  /// an operation their author never wrote. It never *ends* either — a closed
  /// channel reads as the server having dropped it, and the framework would
  /// leave a reconnect timer pending for the test to trip over.
  Stream<SerializableModel> Function(String channel)? answerSubscribe;

  /// Answers `getUploadDescription`. Unset means it throws.
  Future<String?> Function(String path)? answerUploadDescription;

  /// Answers `verifyUpload`. Unset means it throws.
  Future<DwCloudFile?> Function(String path)? answerVerifyUpload;

  /// Forgets everything recorded and every prepared answer.
  void reset() {
    saves.clear();
    deletes.clear();
    reads.clear();
    answerGetOne = null;
    answerGetAll = null;
    answerGetCount = null;
    answerSave = null;
    answerDelete = null;
    answerSubscribe = null;
    answerUploadDescription = null;
    answerVerifyUpload = null;
  }

  @override
  Future<DwApiResponse<DwModelWrapper>> getOne({
    required String className,
    required DwBackendFilter filter,
    String? apiGroup,
  }) {
    final read = DwRecordedRead(
      operation: 'getOne',
      className: className,
      filter: filter,
      apiGroup: apiGroup,
    );
    reads.add(read);
    final answer = answerGetOne;
    if (answer == null) {
      throw DwUnpreparedServerCall(
        'getOne',
        'answerGetOne',
        'className: $className',
      );
    }
    return answer(read);
  }

  @override
  Future<DwApiResponse<List<DwModelWrapper>>> getAll({
    required String className,
    DwBackendFilter? filter,
    List<DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroup,
  }) {
    final read = DwRecordedRead(
      operation: 'getAll',
      className: className,
      filter: filter,
      orderByList: orderByList,
      limit: limit,
      offset: offset,
      apiGroup: apiGroup,
    );
    reads.add(read);
    final answer = answerGetAll;
    if (answer == null) {
      throw DwUnpreparedServerCall(
        'getAll',
        'answerGetAll',
        'className: $className',
      );
    }
    return answer(read);
  }

  @override
  Future<DwApiResponse<int>> getCount({
    required String className,
    DwBackendFilter? filter,
    String? apiGroup,
  }) {
    final read = DwRecordedRead(
      operation: 'getCount',
      className: className,
      filter: filter,
      apiGroup: apiGroup,
    );
    reads.add(read);
    final answer = answerGetCount;
    if (answer == null) {
      throw DwUnpreparedServerCall(
        'getCount',
        'answerGetCount',
        'className: $className',
      );
    }
    return answer(read);
  }

  @override
  Future<DwApiResponse<DwModelWrapper>> saveModel({
    required DwModelWrapper wrappedModel,
    String? apiGroup,
  }) {
    final save = DwRecordedSave(wrappedModel: wrappedModel, apiGroup: apiGroup);
    saves.add(save);
    final answer = answerSave;
    if (answer != null) return answer(save);
    return Future.value(
      DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: wrappedModel,
        updatedModels: <DwModelWrapper>[wrappedModel],
      ),
    );
  }

  @override
  Future<DwApiResponse<bool>> delete({
    required String className,
    required int modelId,
    String? apiGroup,
  }) {
    final delete = DwRecordedDelete(
      className: className,
      modelId: modelId,
      apiGroup: apiGroup,
    );
    deletes.add(delete);
    final answer = answerDelete;
    if (answer != null) return answer(delete);
    return Future.value(const DwApiResponse<bool>(isOk: true, value: true));
  }

  @override
  Stream<SerializableModel> subscribeOnUpdates({required String channel}) =>
      answerSubscribe?.call(channel) ??
      Stream<SerializableModel>.fromFuture(
        Completer<SerializableModel>().future,
      );

  @override
  Future<String?> getUploadDescription({required String path}) {
    final answer = answerUploadDescription;
    if (answer == null) {
      throw DwUnpreparedServerCall(
        'getUploadDescription',
        'answerUploadDescription',
        'path: $path',
      );
    }
    return answer(path);
  }

  @override
  Future<DwCloudFile?> verifyUpload({required String path}) {
    final answer = answerVerifyUpload;
    if (answer == null) {
      throw DwUnpreparedServerCall(
        'verifyUpload',
        'answerVerifyUpload',
        'path: $path',
      );
    }
    return answer(path);
  }
}

/// Names models the way the test declared, and defers to Serverpod's own
/// defaults for everything else.
class _RecordingSerializationManager extends SerializationManager {
  _RecordingSerializationManager(this._classNames);

  final Map<Type, String> _classNames;

  @override
  String? getClassNameForObject(Object? value) {
    if (value == null) return null;
    final declared =
        _classNames[value.runtimeType] ?? super.getClassNameForObject(value);
    if (declared != null) return declared;
    // Falling back to the Dart type name would be silently wrong exactly where
    // it matters most: a generated Serverpod model is an abstract class with a
    // private implementation, so `runtimeType` reads `_NewsPostImpl` and the
    // save would leave under a name no server knows.
    throw StateError(
      'DwRecordingServerTransport does not know what ${value.runtimeType} is '
      'called on the wire.\n'
      'An app passes its own generated Protocol() as serializationManager — it '
      'names every model of the project. A test over an invented model adds it '
      'to classNames: {${value.runtimeType}: \'<TheWireName>\'}.',
    );
  }
}
