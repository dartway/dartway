part of 'dw_app_client.dart';

/// One call on its way to an answer, across its retries.
final class _Call {
  _Call({
    required this.dto,
    required this.url,
    required this.body,
    required this.idempotencyKey,
    required this.timeout,
    required this.token,
  });

  final DwServerCall<Object?> dto;
  final Uri url;

  /// Encoded once: every retry is byte-identical, idempotency key included.
  final String body;

  final String? idempotencyKey;

  /// The deadline, counted from the call; `null` for an entry's reload,
  /// which retries for as long as it is watched.
  final Duration? timeout;

  /// The token to send regardless of the session (a sign-out carries the
  /// token it revokes), as a one-field record so "anonymous" can be pinned
  /// too; `null` sends whatever session is current at each attempt.
  final (String?,)? token;

  final Stopwatch clock = Stopwatch()..start();

  /// The token the last attempt carried.
  String? sentToken;

  String get wireName => dto.dwTypeName;

  Duration? get remaining {
    final timeout = this.timeout;
    return timeout == null ? null : timeout - clock.elapsed;
  }
}

/// How a call ended, as far as the pipeline is concerned.
sealed class _CallOutcome {
  const _CallOutcome();
}

/// The server answered; its updates have been applied.
final class _Answered extends _CallOutcome {
  const _Answered(this.response);

  final DwApiResponse response;
}

/// Something answered that is not a DartWay response.
final class _Unreadable extends _CallOutcome {
  const _Unreadable(this.exception, this.stackTrace);

  final DwProtocolException exception;
  final StackTrace stackTrace;
}

/// No answer before the deadline.
final class _TimedOut extends _CallOutcome {
  const _TimedOut(this.lastError);

  final Object? lastError;
}

/// Nobody waits for the answer any more: the client stopped, or the entry
/// that asked moved on.
final class _Aborted extends _CallOutcome {
  const _Aborted();
}

/// A reply the client may retry: what a proxy or load balancer answers while
/// the server behind it is restarting.
final class _Retryable {
  const _Retryable(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

extension on DwAppClient {
  _Call _newCall(
    DwServerCall<Object?> dto,
    DwPageQuery? page, {
    required Duration? timeout,
    (String?,)? token,
  }) {
    final query = page?.toQuery() ?? const <String, String>{};
    return _Call(
      dto: dto,
      url: baseUrl.replace(
        path: _pathOf(DwHttpContract.callPath(dto.dwTypeName)),
        queryParameters: query.isEmpty ? null : query,
      ),
      body: jsonEncode(dto.toJson()),
      idempotencyKey: dto is DwActionCommand ? _newIdempotencyKey() : null,
      timeout: timeout,
      token: token,
    );
  }

  Future<DwCallResult<R>> _oneShot<R>(
    DwServerCall<R> dto,
    DwPageQuery? page, {
    (String?,)? token,
  }) {
    if (_lifecycle == _Lifecycle.stopped) {
      return Future.error(const DwClientStoppedException());
    }
    final DwCallRefusal? refusal;
    final _Call call;
    try {
      // A throwing validate() or toJson() is the DTO's bug; the caller hears
      // it as such.
      refusal = _localRefusal(dto);
      if (refusal != null) return Future.value(DwCallRefused<R>(refusal));
      if (_incompatibility.value case final incompatible?) {
        return Future.value(DwCallRefused<R>(incompatible));
      }
      call = _newCall(dto, page, timeout: options.callTimeout, token: token);
    } catch (error, stackTrace) {
      return Future.error(error, stackTrace);
    }

    final completer = Completer<DwCallResult<R>>();
    void abort(Object error) {
      if (!completer.isCompleted) completer.completeError(error);
    }

    _pendingCalls.add(abort);
    () async {
          if (!_sessionLoaded.isCompleted) {
            // Asked before start(): the call waits for the session, within its
            // own deadline.
            await _sessionLoaded.future.timeout(
              call.remaining!,
              onTimeout: () {},
            );
            if (!_sessionLoaded.isCompleted) {
              throw DwTimeoutException(call.wireName, options.callTimeout);
            }
          }
          switch (await _send(call)) {
            case _Aborted():
              throw const DwClientStoppedException();
            case _TimedOut(:final lastError):
              throw DwTimeoutException(
                call.wireName,
                options.callTimeout,
                lastError: lastError,
              );
            case _Unreadable(:final exception, :final stackTrace):
              Error.throwWithStackTrace(exception, stackTrace);
            case _Answered(:final response):
              try {
                return response.toResult(dto, protocol);
              } catch (error) {
                // Generated codecs cast and throw TypeError; the envelope
                // throws FormatException. Either way the server sent what
                // this build cannot read.
                throw DwProtocolException(
                  'Cannot decode the result of ${call.wireName}',
                  error,
                );
              }
          }
        }()
        .then(
          (result) {
            if (!completer.isCompleted) completer.complete(result);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        )
        .whenComplete(() => _pendingCalls.remove(abort));
    return completer.future;
  }

  /// Sends [call] until something answers: network failures — and a
  /// gateway's `502`/`503`/`504` without a DartWay body — are retried with
  /// backoff; any DartWay response is final and never retried.
  ///
  /// The response's effects are applied here, before the outcome is handed
  /// on: its updates reach every entry, an incompatibility becomes terminal,
  /// a rejected session ends. The caller's own state change therefore never
  /// runs ahead of the updates that came with it.
  ///
  /// [cancelled] stops retrying for a caller that no longer waits.
  /// [onUnreachable] is told once when the call has gone without an answer
  /// for `callTimeout` — for an entry with no deadline of its own.
  Future<_CallOutcome> _send(
    _Call call, {
    bool Function()? cancelled,
    void Function()? onUnreachable,
  }) async {
    var failures = 0;
    Object? lastError;
    var toldUnreachable = false;
    while (true) {
      if (_lifecycle == _Lifecycle.stopped || (cancelled?.call() ?? false)) {
        return const _Aborted();
      }
      if (_incompatibility.value case final refusal?) {
        // Terminal: this build's calls are answered here, without the
        // network. Already applied, so nothing is absorbed again.
        return _Answered(DwApiIncompatible(refusal));
      }
      final remaining = call.remaining;
      if (remaining != null && remaining <= Duration.zero) {
        return _TimedOut(lastError);
      }
      final pinned = call.token;
      final token = pinned == null ? _session?.token : pinned.$1;
      call.sentToken = token;
      final post = DwHttpPost(
        url: call.url,
        headers: _headersFor(call, token),
        body: call.body,
      );
      // An attempt that hangs is a failure too: without a bound, a server
      // that accepted the connection and never answers would hold an entry
      // forever.
      final attemptLimit = remaining == null || remaining > options.callTimeout
          ? options.callTimeout
          : remaining;
      DwHttpReply? reply;
      try {
        reply = await httpTransport.post(post).timeout(attemptLimit);
      } catch (error) {
        lastError = error;
      }
      if (_lifecycle == _Lifecycle.stopped || (cancelled?.call() ?? false)) {
        return const _Aborted();
      }
      if (reply != null) {
        switch (_read(call, reply)) {
          case final DwApiResponse response:
            _absorb(call, response);
            return _Answered(response);
          case final DwProtocolException exception:
            return _Unreadable(exception, StackTrace.current);
          case final retryable:
            lastError = retryable;
        }
      }
      failures++;
      if (onUnreachable != null &&
          !toldUnreachable &&
          call.clock.elapsed >= options.callTimeout) {
        toldUnreachable = true;
        onUnreachable();
      }
      final delay = _backoff(failures);
      final left = call.remaining;
      if (left != null && left <= Duration.zero) return _TimedOut(lastError);
      await _retryAfter(left == null || delay < left ? delay : left);
    }
  }

  /// The reply as a [DwApiResponse], a [_Retryable], or the
  /// [DwProtocolException] a reply that is neither is.
  Object _read(_Call call, DwHttpReply reply) {
    Object? cause;
    try {
      return DwApiResponse.fromHttp(
        reply.status,
        jsonDecode(reply.body),
        protocol,
      );
    } on FormatException catch (error) {
      cause = error;
    }
    if (reply.status == 502 || reply.status == 503 || reply.status == 504) {
      return _Retryable('HTTP ${reply.status} without a DartWay response');
    }
    return DwProtocolException(
      'The answer to ${call.wireName} (HTTP ${reply.status}) is not a '
      'DartWay response',
      cause,
    );
  }

  Map<String, String> _headersFor(_Call call, String? token) => {
    DwHttpContract.contentTypeHeader: DwHttpContract.jsonContentType,
    DwHttpContract.protocolHeader: '$dwProtocolVersion',
    DwHttpContract.appVersionHeader: '$appVersion',
    if (token != null)
      DwHttpContract.authorizationHeader:
          '${DwHttpContract.bearerPrefix}$token',
    DwHttpContract.idempotencyKeyHeader: ?call.idempotencyKey,
    DwHttpContract.liveConnectionHeader: ?_liveConnectionIdFor(token),
  };

  /// Applies what a response means beyond its result.
  void _absorb(_Call call, DwApiResponse response) {
    switch (response) {
      case DwApiIncompatible(:final refusal):
        _becomeIncompatible(refusal);
      case DwApiOk(replayed: true):
        // The stored outcome of a command that already ran while its answer
        // was lost: its updates went out then, and nothing says they reached
        // this client. What is on screen is read again.
        if (call.sentToken == _session?.token) _rereadAfterReplay();
      case DwApiOk(:final updates) when updates.isNotEmpty:
        // Updates computed for the caller the call went out as. Once the
        // session changed they describe someone else's view: the entries now
        // on screen ask for their own.
        if (call.sentToken == _session?.token) _applyTransport(updates);
      case DwApiUnauthenticated():
        final token = call.sentToken;
        // Only the session the call carried is over; a call that went out
        // before a sign-in says nothing about the new one.
        if (token != null && token == _session?.token) _endSession();
      case DwApiOk() || DwApiRefused() || DwApiFailed():
        break;
    }
  }

  /// Reads every watched request again; an entry nobody watches (waiting out
  /// its release delay) is released instead, so nobody pays for data no
  /// screen shows — a returning screen asks afresh.
  void _rereadAfterReplay() {
    for (final entry in _entries.values.toList()) {
      if (entry.disposed) continue;
      if (entry.watches.isEmpty) {
        _disposeEntry(entry);
      } else {
        unawaited(entry.reload());
      }
    }
  }

  /// Offers each channel's objects of [transport] to the entries whose
  /// requests declare that channel; each takes what its request accepts.
  void _applyTransport(DwUpdateTransport transport) => _applyUpdates([
    for (final MapEntry(key: channel, value: updates)
        in transport.channels.entries)
      (channel, updates.objects),
  ]);

  /// Delivers objects by the channel they were published to (D-036): only an
  /// entry whose request declares the channel hears of them. The channel is
  /// the only fact that says whose data an object is — an admin's command
  /// answers with a member's profile, published to that member's channel,
  /// and routing by type alone would put it into the admin's own profile.
  ///
  /// An entry on several of the channels absorbs once, each object in it
  /// once: the same object published to two channels is one update.
  void _applyUpdates(Iterable<(String channel, List<DwWireObject>)> updates) {
    final byEntry = <_ChannelMember, List<DwWireObject>>{};
    for (final (channel, objects) in updates) {
      for (final entry
          in _channels[channel]?.entries ?? const <_ChannelMember>{}) {
        (byEntry[entry] ??= []).addAll(objects);
      }
    }
    for (final MapEntry(key: entry, value: objects) in byEntry.entries) {
      if (entry.disposed) continue;
      entry.absorb(
        objects.length == 1 ? objects : DwChannelUpdates(objects).objects,
      );
    }
  }

  /// Waits [delay] before a retry, or less: a live socket that says hello
  /// means the network is back, and every waiting retry goes at once.
  Future<void> _retryAfter(Duration delay) {
    final waiter = Completer<void>();
    final timer = Timer(delay, () {
      if (!waiter.isCompleted) waiter.complete();
    });
    _retryWaiters.add(waiter);
    return waiter.future.whenComplete(() {
      timer.cancel();
      _retryWaiters.remove(waiter);
    });
  }

  void _wakeRetries() {
    for (final waiter in _retryWaiters.toList()) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }
}
