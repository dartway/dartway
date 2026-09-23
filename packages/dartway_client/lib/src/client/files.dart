part of 'dw_app_client.dart';

/// File uploads of a client: `client.files`.
///
/// An upload is three steps, and the bytes never pass through the app
/// server: the server issues a ticket (`DwStartUpload`), the client puts the
/// bytes to storage by the ticket's presigned URL, and the server confirms
/// what storage holds (`DwFinishUpload`). Picking a file is the app's
/// business; this takes bytes or a stream.
final class DwFileClient {
  DwFileClient._(this._client);

  final DwAppClient _client;

  /// Uploads [source] for [purpose] and answers the stored file.
  ///
  /// The ticket's refusals — a size or type the purpose does not take, a
  /// caller who may not upload, too many unfinished uploads — and the
  /// confirmation's (`dw.uploadMissing`, `dw.uploadMismatch`,
  /// `dw.uploadExpired`) arrive as [DwCallRefused], as every refusal does.
  /// Both server calls are retried and time out like any command
  /// ([DwTimeoutException]).
  ///
  /// The put is retried with backoff after network failures, stalls (no
  /// progress for `options.callTimeout`) and storage's transient answers
  /// (`408`, `429`, `5xx`) for as long as the ticket is valid. An attempt
  /// whose upload arrived while its answer was lost is recognised on the
  /// retry: storage refuses to overwrite the object (`412`), and the upload
  /// goes on to confirmation, which checks what is stored. When the bytes
  /// cannot be delivered, the future completes with [DwUploadException].
  ///
  /// [onProgress] receives the bytes sent and the total: `(0, total)` when an
  /// attempt begins — again after a retry — and `(total, total)` once storage
  /// has the file, before the confirmation.
  ///
  /// Throws [StateError] when [source] yields another number of bytes than
  /// its `byteSize` — the caller's bug, not retried.
  ///
  /// When [cancel] completes before the upload is confirmed, the transfer is
  /// aborted, no confirmation is sent, and the future completes with
  /// [DwUploadCancelledException]. The ticket stays unfinished, so the
  /// server's cleanup of unfinished uploads removes it with whatever bytes
  /// arrived — a cancelled gigabyte does not stay in the bucket (#284). Once
  /// the confirmation is sent the file is the caller's, cancelled or not.
  Future<DwCallResult<DwStoredFile>> upload(
    DwUploadPurpose purpose,
    DwUploadSource source, {
    required String fileName,
    required String contentType,
    void Function(int sentBytes, int totalBytes)? onProgress,
    Future<void>? cancel,
  }) async {
    final cancellation = _Cancellation(cancel);
    final started = await _client.command(
      DwStartUpload(
        purpose: purpose,
        fileName: fileName,
        contentType: contentType,
        byteSize: source.byteSize,
      ),
    );
    final DwUploadTicket ticket;
    switch (started) {
      case DwCallOk(:final value):
        ticket = value;
      case DwCallRefused(:final refusal):
        return DwCallRefused(refusal);
      case DwNotAuthenticated():
        return const DwNotAuthenticated();
      case DwCallFailed(:final incidentId):
        return DwCallFailed(incidentId);
    }
    cancellation.check();
    await _put(ticket, source, onProgress, cancellation);
    cancellation.check();
    return _client.command(DwFinishUpload(ticketId: ticket.id));
  }

  /// A link to read file [fileId]: a short-lived one for a private file, its
  /// URL for a public one. Fetch it when the file is about to be shown.
  Future<DwCallResult<DwFileLink>> getLink(int fileId) =>
      _client.fetch(DwGetFileLink(fileId: fileId));

  Future<void> _put(
    DwUploadTicket ticket,
    DwUploadSource source,
    void Function(int sentBytes, int totalBytes)? onProgress,
    _Cancellation cancellation,
  ) async {
    final client = _client;
    final url = Uri.parse(ticket.uploadUrl);
    final total = source.byteSize;
    var failures = 0;
    Object? lastError;
    int? lastStatus;
    String? lastCode;

    // Out of time with only network failures and transient answers behind:
    // unreachable, with the last answer storage gave, if any.
    DwUploadException giveUp() => DwUploadException(
      DwUploadFailure.unreachable,
      status: lastStatus,
      storageCode: lastCode,
      lastError: lastError,
    );

    while (true) {
      if (client._lifecycle == _Lifecycle.stopped) {
        throw const DwClientStoppedException();
      }
      cancellation.check();
      final attempt = _Attempt(
        source: source,
        total: total,
        stallTimeout: client.options.callTimeout,
        onProgress: onProgress,
      );
      void abort(Object error) => attempt.abort(error);
      client._pendingCalls.add(abort);
      cancellation.onCancel = () =>
          attempt.abort(const DwUploadCancelledException());
      DwStorageReply? reply;
      try {
        reply = await client.storageTransport.put(
          DwStoragePut(
            url: url,
            headers: ticket.headers,
            byteSize: total,
            body: attempt.body,
            abort: attempt.aborted,
          ),
        );
      } catch (error) {
        lastError = error;
      } finally {
        client._pendingCalls.remove(abort);
        cancellation.onCancel = null;
        attempt.finish();
      }
      if (attempt.stoppedBy case final error?) throw error;
      if (attempt.sourceError case final error?) {
        Error.throwWithStackTrace(error, attempt.sourceStackTrace!);
      }

      if (reply != null) {
        final status = reply.status;
        // 412: the key is taken, and only this ticket could have taken it —
        // an earlier attempt arrived. Confirmation checks what is stored.
        if ((status >= 200 && status < 300) || status == 412) {
          onProgress?.call(total, total);
          return;
        }
        lastStatus = status;
        lastCode = RegExp(
          r'<Code>([^<]+)</Code>',
        ).firstMatch(reply.body)?.group(1);
        final transient =
            status == 408 || status == 429 || (status >= 500 && status < 600);
        if (!transient) {
          throw DwUploadException(
            DateTime.now().isAfter(ticket.expiresAt)
                ? DwUploadFailure.expired
                : DwUploadFailure.rejected,
            status: status,
            storageCode: lastCode,
          );
        }
        lastError = 'HTTP $status${lastCode == null ? '' : ' $lastCode'}';
      }

      failures++;
      final left = ticket.expiresAt.difference(DateTime.now());
      if (left <= Duration.zero) throw giveUp();
      final delay = client._backoff(failures);
      await Future.any([
        client._retryAfter(delay < left ? delay : left),
        cancellation.cancelled,
      ]);
      cancellation.check();
      if (!DateTime.now().isBefore(ticket.expiresAt)) throw giveUp();
    }
  }
}

/// An upload's cancellation: whether it was asked for, and the running
/// attempt to abort when it is.
final class _Cancellation {
  _Cancellation(Future<void>? cancel) {
    cancel?.then((_) {
      _requested = true;
      if (!_signal.isCompleted) _signal.complete();
      onCancel?.call();
    });
  }

  bool _requested = false;
  final Completer<void> _signal = Completer<void>();

  /// Completes when the upload is cancelled; never, when it cannot be.
  Future<void> get cancelled => _signal.future;

  /// Aborts the attempt running now.
  void Function()? onCancel;

  void check() {
    if (_requested) throw const DwUploadCancelledException();
  }
}

/// One put attempt: its body counted as the transport takes it, a watchdog
/// for a stalled network, and the ways it can be ended from outside.
final class _Attempt {
  _Attempt({
    required DwUploadSource source,
    required this.total,
    required this.stallTimeout,
    required this.onProgress,
  }) : _source = source {
    // From the start, not from the first byte: a transport that never takes
    // the body is as stalled as one that stops taking it.
    _armWatchdog();
  }

  final DwUploadSource _source;
  final int total;
  final Duration stallTimeout;
  final void Function(int sentBytes, int totalBytes)? onProgress;

  final Completer<void> _aborted = Completer<void>();
  Timer? _watchdog;
  int _sent = 0;
  bool _failed = false;

  /// Bytes sent when progress was last reported. Reported again after another
  /// hundredth of the total, and at the last byte: at most about a hundred
  /// calls per attempt whatever the chunk size, and the same calls whatever
  /// the speed — a fast network would otherwise call back per chunk.
  int _reported = 0;

  /// Set when the client stopped during the attempt.
  Object? stoppedBy;

  /// Set when the source misbehaved: a caller's bug, never retried.
  Object? sourceError;
  StackTrace? sourceStackTrace;

  /// Completes when the attempt is to end now.
  Future<void> get aborted => _aborted.future;

  void abort(Object error) {
    stoppedBy ??= error;
    _abort();
  }

  void _abort() {
    if (!_aborted.isCompleted) _aborted.complete();
  }

  /// No byte taken and no answer for [stallTimeout]: the connection is dead
  /// in a way the socket has not noticed.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(stallTimeout, _abort);
  }

  void finish() {
    _watchdog?.cancel();
    _abort();
  }

  late final Stream<List<int>> body = () {
    onProgress?.call(0, total);
    return _source.open().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          if (_failed) return;
          _sent += chunk.length;
          if (_sent > total) {
            _failSource(
              StateError(
                'The upload source yielded more than its byteSize of $total',
              ),
              sink,
            );
            return;
          }
          _armWatchdog();
          if (_sent == total || (_sent - _reported) * 100 >= total) {
            _reported = _sent;
            onProgress?.call(_sent, total);
          }
          sink.add(chunk);
        },
        handleError: (error, stackTrace, sink) {
          sourceError ??= error;
          sourceStackTrace ??= stackTrace;
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          if (_failed) return;
          if (_sent != total) {
            _failSource(
              StateError(
                'The upload source yielded $_sent bytes, and its byteSize is '
                '$total',
              ),
              sink,
            );
            return;
          }
          sink.close();
        },
      ),
    );
  }();

  void _failSource(StateError error, EventSink<List<int>> sink) {
    final stackTrace = StackTrace.current;
    _failed = true;
    sourceError ??= error;
    sourceStackTrace ??= stackTrace;
    sink
      ..addError(error, stackTrace)
      ..close();
    _abort();
  }
}
