import 'dart:async';
import 'dart:typed_data';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../transport/dw_storage_transport.dart';
import 'dw_fake_server.dart';

/// A stored object of [DwFakeStorage].
final class DwFakeObject {
  const DwFakeObject(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;
}

/// File uploads for tests of a client and the screens on top of it: the
/// framework's file calls answered by a [DwFakeServer], and a storage in
/// memory behind [transport] that holds a ticket to what a presigned URL
/// holds real clients to — the signed length and type, no overwrite.
///
/// ```dart
/// final server = DwFakeServer(protocol: appProtocol);
/// final storage = DwFakeStorage(server);
/// final client = server.newClient(storageTransport: storage.transport);
/// ```
///
/// Not the real storage rules: no purposes, no limits beyond [refuseStart],
/// no permissions. What it reproduces is the sequence a client goes through
/// and the ways each step can go wrong.
final class DwFakeStorage {
  DwFakeStorage(this.server) {
    server
      ..onCommand<DwStartUpload>(_start)
      ..onCommand<DwFinishUpload>(_finish)
      ..onRequest<DwGetFileLink>(_link);
  }

  final DwFakeServer server;

  /// Refuses a start when it returns a refusal: a size, a type, a permission.
  DwCallRefusal? Function(DwStartUpload command)? refuseStart;

  /// Puts that fail on the network before storing anything, one per put.
  int failPuts = 0;

  /// Puts that store the object and then fail on the network: the answer is
  /// lost, the upload arrived.
  int loseAnswers = 0;

  /// Statuses storage answers instead of storing, one per put.
  final List<int> answerStatuses = [];

  /// A pause before each chunk of a body is read — for watching progress.
  Duration chunkDelay = Duration.zero;

  /// How long a ticket lasts.
  Duration ticketLifetime = const Duration(minutes: 15);

  /// Objects by ticket id.
  final Map<int, DwFakeObject> objects = {};

  /// Every put that reached storage, stored or not.
  int puts = 0;

  int _nextId = 1;
  final Map<int, DwStartUpload> _tickets = {};
  final Map<int, int?> _owners = {};
  final Set<int> _confirmed = {};

  static final Uri _storage = Uri.parse('https://storage.test');

  /// Carries uploads to this storage.
  late final DwMemoryStorageTransport transport = DwMemoryStorageTransport(
    _put,
  );

  /// The files confirmed so far.
  List<DwStoredFile> get files => [for (final id in _confirmed) _fileOf(id)];

  DwCallResult<Object?> _start(DwStartUpload command, DwFakeCall call) {
    if (call.accountId == null) return const DwNotAuthenticated<Object?>();
    final refusals = command.validate();
    if (refusals.isNotEmpty) return DwCallRefused(refusals.first);
    if (refuseStart?.call(command) case final refusal?) {
      return DwCallRefused(refusal);
    }
    final id = _nextId++;
    _tickets[id] = command;
    _owners[id] = call.accountId;
    return DwCallOk(
      DwUploadTicket(
        id: id,
        uploadUrl: '$_storage/objects/$id?signature=fake',
        headers: {'content-type': command.contentType, 'if-none-match': '*'},
        expiresAt: DateTime.now().toUtc().add(ticketLifetime),
      ),
    );
  }

  Future<DwStorageReply> _put(DwStoragePut put) async {
    puts++;
    final id = int.tryParse(put.url.pathSegments.last);
    final ticket = id == null ? null : _tickets[id];
    final builder = BytesBuilder(copy: false);
    // Read as a network would, so the client's progress and stall detection
    // see a transfer: reported the same way `DwHttpStorageTransport` reports
    // it, chunk by chunk as this fake pulls the body.
    final subscription = put.body.listen(null);
    final done = Completer<void>();
    subscription
      ..onData((chunk) async {
        builder.add(chunk);
        put.reportSent(builder.length);
        if (chunkDelay > Duration.zero) {
          subscription.pause();
          await Future<void>.delayed(chunkDelay);
          subscription.resume();
        }
      })
      ..onError((Object error, StackTrace stackTrace) {
        if (!done.isCompleted) done.completeError(error, stackTrace);
      })
      ..onDone(() {
        if (!done.isCompleted) done.complete();
      });
    unawaited(
      put.abort.then((_) {
        if (!done.isCompleted) {
          unawaited(subscription.cancel());
          done.completeError(StateError('the put was aborted'));
        }
      }),
    );
    await done.future;

    if (failPuts > 0) {
      failPuts--;
      throw const DwFakeNetworkException();
    }
    if (answerStatuses.isNotEmpty) {
      return DwStorageReply(status: answerStatuses.removeAt(0));
    }
    final bytes = builder.takeBytes();
    if (ticket == null ||
        put.headers['content-type'] != ticket.contentType ||
        bytes.length != ticket.byteSize ||
        put.byteSize != ticket.byteSize) {
      return const DwStorageReply(
        status: 403,
        body: '<Error><Code>SignatureDoesNotMatch</Code></Error>',
      );
    }
    if (objects.containsKey(id)) {
      return const DwStorageReply(
        status: 412,
        body: '<Error><Code>PreconditionFailed</Code></Error>',
      );
    }
    objects[id!] = DwFakeObject(bytes, ticket.contentType);
    if (loseAnswers > 0) {
      loseAnswers--;
      throw const DwFakeNetworkException();
    }
    return const DwStorageReply(status: 200);
  }

  DwCallResult<Object?> _finish(DwFinishUpload command, DwFakeCall call) {
    final id = command.ticketId;
    if (call.accountId == null) return const DwNotAuthenticated<Object?>();
    if (!_tickets.containsKey(id) || _owners[id] != call.accountId) {
      return DwCallRefused(DwCallRefusal(DwCoreRefusal.notFound));
    }
    if (!objects.containsKey(id)) {
      return DwCallRefused(DwCallRefusal(DwUploadRefusal.missing));
    }
    _confirmed.add(id);
    return DwCallOk(_fileOf(id));
  }

  DwCallResult<Object?> _link(DwGetFileLink request, DwFakeCall call) {
    final id = request.fileId;
    if (!_confirmed.contains(id)) {
      return DwCallRefused(DwCallRefusal(DwCoreRefusal.notFound));
    }
    return DwCallOk(
      DwFileLink(
        id: id,
        url: '$_storage/objects/$id?read=fake',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      ),
    );
  }

  DwStoredFile _fileOf(int id) {
    final ticket = _tickets[id]!;
    return DwStoredFile(
      id: id,
      purpose: ticket.purpose,
      fileName: ticket.fileName,
      contentType: ticket.contentType,
      byteSize: ticket.byteSize,
      url: '$_storage/objects/$id',
    );
  }
}
