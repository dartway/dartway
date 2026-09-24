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
            reportSent: attempt.reportSent,
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

/// One put attempt: its body read and validated, a watchdog for a stalled
/// network, and the ways it can be ended from outside.
///
/// The watchdog is always [stallTimeout] — there is no separate, longer
/// phase for "the whole body is sent, now wait for the reply": a first
/// version of this tried one, bounded by the upload ticket's remaining
/// validity, reasoning that a transport confirming the whole body sent
/// through [reportSent] had proven the connection alive. It had not: on
/// `dart:io`, `DwHttpStorageTransport` calls [reportSent] as it *pulls* a
/// chunk into the socket, which for a body that fits the OS send buffer can
/// mean the whole body in one go — a live pull, not a delivered byte. A
/// storage host that accepts the connection and then answers nothing (a
/// dropped path an OS has not noticed) turned from "retried every
/// `callTimeout`" into "silently stuck for up to the ticket's lifetime"
/// (#309, found in review). The watchdog re-arming on every real progress
/// signal already does the useful part: a transfer that is still moving is
/// never mistaken for dead, whatever "still moving" means for the transport
/// in front of it.
///
/// Reading [body] and reporting progress through [reportSent] are two
/// different facts, still. A transport that streams the body at the
/// network's pace can treat them as the same thing — `DwHttpStorageTransport`
/// does — but one that reads the whole body into memory before sending it —
/// a browser's `fetch`, or `XMLHttpRequest`, which cannot stream a request
/// body at all — cannot, and treating "read" as "sent" is exactly how a
/// stalled transfer used to stop being noticed (#309): the body was read in
/// an instant, the watchdog was armed once at the very start, and nothing
/// armed it again while the real transfer — or its failure — happened in
/// silence.
///
/// So there are two independent sources of "the pipeline is alive": reading
/// [body] (§[_produced], always) and a transport's own [reportSent]. Before
/// a transport ever calls [reportSent], reading also drives progress —
/// exactly the old, pre-#309 behaviour, so a transport that never adopts
/// [reportSent] loses nothing. The moment a transport calls it once, reading
/// stops driving progress (it still keeps the watchdog alive on its own,
/// for a slow *source* — a big file read off disk, say — which is not a
/// stalled network): from there, only [reportSent] speaks for what the
/// network is doing.
final class _Attempt {
  _Attempt({
    required DwUploadSource source,
    required this.total,
    required this.stallTimeout,
    required this.onProgress,
  }) : _source = source {
    onProgress?.call(0, total);
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

  /// Bytes read from [_source] so far — validates it yields exactly [total],
  /// nothing more, nothing less; drives progress too, until a transport
  /// calls [reportSent] for the first time. See the class doc.
  int _produced = 0;

  /// Bytes a transport has confirmed sent, through [reportSent].
  int _sent = 0;

  /// Set on the first call to [reportSent]: from there, progress comes only
  /// from it, never again from reading [body].
  bool _reportedByTransport = false;

  bool _failed = false;

  /// Bytes reported when progress was last reported — whichever of
  /// [_produced] or [_sent] is driving it. Reported again after another
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

  /// No sign of life for [stallTimeout]: the connection is dead in a way the
  /// socket has not noticed.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(stallTimeout, _abort);
  }

  void finish() {
    _watchdog?.cancel();
    _abort();
  }

  /// The transport's report of bytes actually sent so far (`DwStoragePut`'s
  /// doc has the full contract). Re-arms the watchdog and reports progress;
  /// from the first call on, reading [body] no longer drives progress on its
  /// own (the class doc). Never decreasing in what it reports, and ignored
  /// once the attempt has already ended.
  void reportSent(int sentBytes) {
    if (_aborted.isCompleted) return;
    _reportedByTransport = true;
    if (sentBytes <= _sent) return;
    _sent = sentBytes > total ? total : sentBytes;
    _armWatchdog();
    if (_sent == total || (_sent - _reported) * 100 >= total) {
      _reported = _sent;
      onProgress?.call(_sent, total);
    }
  }

  late final Stream<List<int>> body = _source.open().transform(
    StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        if (_failed) return;
        _produced += chunk.length;
        if (_produced > total) {
          _failSource(
            StateError(
              'The upload source yielded more than its byteSize of $total',
            ),
            sink,
          );
          return;
        }
        // A chunk left the source: the pipeline is alive, whatever it turns
        // out to mean for the network — see the class doc. True regardless
        // of `_reportedByTransport`: a slow *source* is never mistaken for a
        // stalled network, whichever of the two is driving progress.
        _armWatchdog();
        sink.add(chunk);
        // After handing the chunk on, not before: `fromHandlers` delivers
        // synchronously (a `sync` controller underneath), so a transport
        // that calls `reportSent` for this same chunk — from inside its own
        // `onData`, listening downstream of `sink.add` above — has already
        // done so by the time control returns here. `_reportedByTransport`
        // is therefore never stale: a transport reporting for the first
        // time never leaves a stray, out-of-order progress call behind it.
        if (_aborted.isCompleted || _failed || _reportedByTransport) return;
        if (_produced == total || (_produced - _reported) * 100 >= total) {
          _reported = _produced;
          onProgress?.call(_produced, total);
        }
      },
      handleError: (error, stackTrace, sink) {
        sourceError ??= error;
        sourceStackTrace ??= stackTrace;
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        if (_failed) return;
        if (_produced != total) {
          _failSource(
            StateError(
              'The upload source yielded $_produced bytes, and its byteSize '
              'is $total',
            ),
            sink,
          );
          return;
        }
        sink.close();
      },
    ),
  );

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
