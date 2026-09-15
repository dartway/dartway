import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_alert_sink.dart';
import '../alerts/dw_server_logger.dart';
import '../auth/dw_auth_service.dart';
import '../context/dw_call_context.dart';
import '../handlers/dw_call_handler.dart';
import '../http/dw_request_body.dart';
import '../server/dw_runtime.dart';
import '../server/dw_server_settings.dart';

/// Answers `POST /dw/<WireName>`: the call contract of R2.2, from the headers
/// to the `DwApiResponse`.
///
/// Checks run cheapest first, and nothing touches the database until the
/// call is known to be well-formed:
///
/// 1. `Dw-Protocol` (missing: 400; another version: 426) and
///    `Dw-App-Version` (below `minAppBuild`: 426) — an incompatible client
///    learns that before anything else, whatever else it got wrong;
/// 2. the method, the wire name (unknown: 404), the content type, the
///    idempotency key (required for a command, forbidden for a request), the
///    live connection and authorization headers, the query and the body —
///    each a malformed call (400) when wrong;
/// 3. the token (unknown or revoked: 401 — a client holding a dead token must
///    learn it on any call, not only on one that needs an account);
/// 4. the access rule's sign-in requirement (401), validation — the table
///    page check and `DwSelfValidating.validate` (422) — and the access check
///    (403);
/// 5. the handler.
///
/// Sign-in is checked before validation so an anonymous caller is told to
/// sign in rather than which field is wrong; validation before the access
/// check because it is pure, while a check may query, and a check written
/// against the call's fields should not run on fields that are invalid.
@internal
final class DwCallEndpoint {
  DwCallEndpoint({
    required this.runtime,
    required this.authService,
    required this.settings,
    required this.handlers,
  });

  final DwRuntime runtime;
  final DwAuthService authService;
  final DwServerSettings settings;

  /// By call class; one per request and command class of the protocol.
  final Map<Type, DwCallHandler> handlers;

  static const int _maxTransactionAttempts = 3;
  static const int maxIdempotencyKeyLength = 128;

  DwWireProtocol get _protocol => runtime.protocol;
  DwServerLogger get _log => runtime.log;

  /// Answers one call. Never throws: every outcome is a response.
  Future<DwApiResponse> answer(HttpRequest http, DwRequestBody body) async {
    try {
      return await _answer(http, body);
    } on _Rejected catch (rejection) {
      return rejection.response;
    } catch (error, stackTrace) {
      return DwApiResponse.failed(
        runtime.alerts.report(
          where: 'call ${http.uri.path}',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<DwApiResponse> _answer(HttpRequest http, DwRequestBody body) async {
    final path = http.uri.path;

    // 1. Compatibility.
    final protocolVersion = _header(http, DwHttpContract.protocolHeader);
    if (protocolVersion == null) {
      _malformed(
        path,
        'the ${DwHttpContract.protocolHeader} header is missing',
      );
    }
    if (protocolVersion != '$dwProtocolVersion') {
      return DwApiResponse.incompatible(
        DwCallRefusal(DwCoreRefusal.protocolUnsupported),
      );
    }
    final appVersion = _header(http, DwHttpContract.appVersionHeader);
    final int build;
    if (appVersion == null) {
      // A client that says nothing is as old as a client can be.
      build = 0;
    } else {
      try {
        build = DwAppVersion.parse(appVersion).build;
      } on FormatException catch (error) {
        _malformed(
          path,
          'the ${DwHttpContract.appVersionHeader} header',
          error,
        );
      }
    }
    if (build < settings.minAppBuild) {
      return DwApiResponse.incompatible(
        DwCallRefusal(DwCoreRefusal.updateRequired),
      );
    }

    // 2. Shape.
    if (http.method != DwHttpContract.callMethod) {
      _malformed(
        path,
        'a call is ${DwHttpContract.callMethod}, not ${http.method}',
      );
    }
    final name = DwHttpContract.wireNameOf(path);
    final entry = name == null ? null : _protocol.entryNamed(name);
    final handler = entry == null ? null : handlers[entry.type];
    if (name == null || handler == null) {
      final incident = DwServerIncident.newId();
      _log.warning('unknown call $path (incident $incident)');
      return DwApiResponse.failed(incident, failure: DwFailureKind.unknownCall);
    }
    _checkContentType(http, path);
    final isCommand = handler is DwCommandHandler;
    final key = _header(http, DwHttpContract.idempotencyKeyHeader);
    if (isCommand) {
      if (key == null || key.isEmpty) {
        _malformed(
          path,
          'a command needs ${DwHttpContract.idempotencyKeyHeader}',
        );
      }
      if (key.length > maxIdempotencyKeyLength) {
        _malformed(
          path,
          'the idempotency key is over $maxIdempotencyKeyLength characters',
        );
      }
    } else if (key != null) {
      _malformed(
        path,
        'a request takes no ${DwHttpContract.idempotencyKeyHeader}',
      );
    }
    final liveConnectionId = _header(http, DwHttpContract.liveConnectionHeader);
    final token = dwBearerToken(
      _header(http, DwHttpContract.authorizationHeader),
      (what) => _malformed(path, what),
    );
    final query = _query(http, path);
    final call = await _decode(http, body, entry!, handler, path);

    final Object? prepared;
    switch ((call, handler)) {
      case (DwDataRequest<Object?> request, DwRequestHandler handler):
        try {
          prepared = handler.prepare(
            request,
            DwPageQuery.parse(request, query),
          );
        } on FormatException catch (error) {
          _malformed(path, 'the query', error);
        }
      case (DwActionCommand<Object?> _, DwCommandHandler _):
        if (query.isNotEmpty) _malformed(path, 'a command takes no query');
        prepared = null;
      default:
        throw StateError(
          '$name is registered as ${entry.kind.name} and '
          'handled by $handler',
        );
    }

    // 3. Who calls.
    DwSessionKeyInfo? session;
    if (token != null) {
      session = await authService.resolve(token);
      if (session == null) return const DwApiResponse.unauthenticated();
    }

    // 4 and 5.
    return switch ((call, handler)) {
      (DwDataRequest<Object?> request, DwRequestHandler handler) =>
        await _runRequest(handler, request, prepared, session, name),
      (DwActionCommand<Object?> command, DwCommandHandler handler) =>
        await _runCommand(
          handler,
          command,
          key!,
          session,
          liveConnectionId,
          name,
          (appVersion, _header(http, HttpHeaders.userAgentHeader)),
        ),
      _ => throw StateError('unreachable'),
    };
  }

  Future<DwApiResponse> _runRequest(
    DwRequestHandler handler,
    DwDataRequest<Object?> request,
    Object? prepared,
    DwSessionKeyInfo? session,
    String name,
  ) async {
    final where = 'request $name';
    final ctx = runtime.context(
      scope: where,
      kind: DwContextKind.request,
      sessionKey: session,
    );
    try {
      _requireSignIn(handler.access, ctx);
      _validate(request);
      await _check(handler.access, ctx, request);
      return DwApiResponse.ok(await handler.run(ctx, request, prepared));
    } catch (error, stackTrace) {
      return _answerError(where, error, stackTrace, ctx);
    }
  }

  Future<DwApiResponse> _runCommand(
    DwCommandHandler handler,
    DwActionCommand<Object?> command,
    String key,
    DwSessionKeyInfo? session,
    String? liveConnectionId,
    String name,
    (String?, String?) client,
  ) async {
    final where = 'command $name';
    final accountId = session?.accountId;
    final ctx = runtime.context(
      scope: where,
      kind: DwContextKind.command,
      sessionKey: session,
      clientAppVersion: client.$1,
      clientUserAgent: client.$2,
    );
    DwApiResponse response;
    try {
      response = await _executeCommand(handler, command, key, ctx, name);
    } catch (error, stackTrace) {
      response = _answerError(where, error, stackTrace, ctx);
    }
    // Only a response that carries the updates relieves the caller's own
    // connection of them: after a refusal or a failure — a non-transactional
    // command may have committed and published before it ended so — that
    // connection hears them over the socket like every other.
    if (response is! DwApiOk) {
      runtime.deliver(ctx);
      return response;
    }
    // Looked up after commit, not before: the connection may have closed or
    // signed in as someone else while the command ran.
    final author = runtime.hub.connectionOf(liveConnectionId, accountId);
    return DwApiResponse.ok(
      response.result,
      updates: await runtime.answer(ctx, author: author),
      replayed: response.replayed,
    );
  }

  Future<DwApiResponse> _executeCommand(
    DwCommandHandler handler,
    DwActionCommand<Object?> command,
    String key,
    DwRuntimeContext ctx,
    String typeName,
  ) async {
    final accountId = ctx.accountId;
    // A transactional command looks its key up inside its transaction, under
    // the key's lock; looking here as well would cost every first send a
    // round trip.
    if (!handler.transactional) {
      final stored = await _storedOutcome(runtime.db, key, accountId);
      if (stored != null) return _replay(stored, typeName);
    }
    _requireSignIn(handler.access, ctx);
    try {
      _validate(command);
      if (!handler.transactional) {
        await _check(handler.access, ctx, command);
        final value = await handler.run(ctx, command);
        if (handler.recordsSuccess && !ctx.madeSecret) {
          await _record(runtime.db, key, accountId, typeName, 'ok', value);
        }
        return DwApiResponse.ok(value);
      }
      for (var attempt = 1; ; attempt++) {
        try {
          return await ctx.transaction((tx) async {
            // Two sends of one key racing each other: the second waits here
            // and then finds the first one's outcome.
            await tx.advisoryLock(
              DwLockSpace.idempotencyKey,
              dwLockKey('$accountId/$key'),
            );
            final stored = await _storedOutcome(tx, key, accountId);
            if (stored != null) return _replay(stored, typeName);
            await _check(handler.access, ctx, command);
            final value = await handler.run(ctx, command);
            if (handler.recordsSuccess && !ctx.madeSecret) {
              await _record(tx, key, accountId, typeName, 'ok', value);
            }
            return DwApiResponse.ok(value);
          });
        } catch (error) {
          if (attempt < _maxTransactionAttempts &&
              dwIsRetryableTransactionError(error)) {
            ctx.log.info('transaction conflict, attempt $attempt; retrying');
            ctx.resetForRetry();
            continue;
          }
          rethrow;
        }
      }
    } on DwRefusalException catch (refusal) {
      // The transaction has rolled back; the refusal is the outcome, and a
      // retry of the same intent is answered the same.
      await _record(
        runtime.db,
        key,
        accountId,
        typeName,
        'refused',
        refusal.refusal.toJson(),
      );
      rethrow;
    }
  }

  void _requireSignIn(DwAccessRule access, DwCallContext ctx) {
    if (access is! DwAnonymousAccess && ctx.accountId == null) {
      throw const DwNotAuthenticatedException();
    }
  }

  Future<void> _check(
    DwAccessRule access,
    DwCallContext ctx,
    DwServerCall<Object?> call,
  ) async {
    if (access is DwCheckAccess && !await access.allows(ctx, call)) {
      ctx.refuse(DwCoreRefusal.forbidden);
    }
  }

  /// The client ran the same checks before sending; running them again is
  /// what makes them rules rather than courtesies of well-behaved clients.
  void _validate(DwServerCall<Object?> call) {
    if (call case final DwTableRequest<DwDataObject> table) {
      if (table.checkPage() case final refusal?) {
        throw DwRefusalException(refusal);
      }
    }
    if (call case final DwSelfValidating validating) {
      final refusals = validating.validate();
      if (refusals.isNotEmpty) throw DwRefusalException(refusals.first);
    }
  }

  DwApiResponse _replay(_StoredOutcome stored, String typeName) {
    if (stored.type != typeName) {
      // One key, two intents: a client bug that must not execute either way.
      return DwApiResponse.refused(
        DwCallRefusal(
          DwCoreRefusal.conflict,
          params: {'idempotencyKey': 'reused'},
        ),
      );
    }
    return stored.status == 'ok'
        ? DwApiResponse.ok(stored.result, replayed: true)
        : _refused(DwCallRefusal.fromJson(stored.result));
  }

  DwApiResponse _answerError(
    String where,
    Object error,
    StackTrace stackTrace,
    DwCallContext ctx,
  ) => switch (error) {
    DwRefusalException(:final refusal) => _refused(refusal),
    DwNotAuthenticatedException() => const DwApiResponse.unauthenticated(),
    _ => DwApiResponse.failed(
      runtime.alerts.report(
        where: where,
        error: error,
        stackTrace: stackTrace,
        accountId: ctx.accountId,
      ),
    ),
  };

  /// A handler may refuse with an incompatibility too (a feature this build
  /// of the app cannot use): that is answered as one, 426.
  static DwApiResponse _refused(DwCallRefusal refusal) =>
      refusal.isIncompatibility
      ? DwApiResponse.incompatible(refusal)
      : DwApiResponse.refused(refusal);

  // --- reading the call -------------------------------------------------------

  /// The single value of [name], `null` when absent. A header sent twice is
  /// a malformed call: which of two tokens or two keys is meant cannot be
  /// guessed.
  String? _header(HttpRequest http, String name) {
    final values = http.headers[name];
    if (values == null || values.isEmpty) return null;
    if (values.length > 1) {
      _malformed(http.uri.path, 'the $name header is repeated');
    }
    return values.single;
  }

  /// Only JSON is accepted — which also keeps browsers from sending a call
  /// cross-origin without a preflight the server never answers.
  void _checkContentType(HttpRequest http, String path) {
    final ContentType? type;
    try {
      type = http.headers.contentType;
    } on HttpException {
      _malformed(path, 'the Content-Type header is repeated');
    }
    final charset = type?.charset?.toLowerCase();
    if (type?.mimeType != 'application/json' ||
        (charset != null && charset != 'utf-8')) {
      _malformed(path, 'the body of a call is application/json in UTF-8');
    }
  }

  Map<String, String> _query(HttpRequest http, String path) {
    final all = http.uri.queryParametersAll;
    if (all.isEmpty) return const {};
    return {
      for (final MapEntry(:key, :value) in all.entries)
        key: value.length == 1
            ? value.single
            : _malformed(path, 'the query parameter "$key" is repeated'),
    };
  }

  Future<DwServerCall<Object?>> _decode(
    HttpRequest http,
    DwRequestBody body,
    DwProtocolEntry entry,
    DwCallHandler handler,
    String path,
  ) async {
    final Object? json;
    try {
      final bytes = await body.read(
        handler.maxBodyBytes ?? settings.maxBodyBytes,
      );
      json = const Utf8Decoder().fuse(const JsonDecoder()).convert(bytes);
    } on DwRequestBodyException catch (error) {
      _malformed(path, error.message);
    } on FormatException catch (error) {
      _malformed(path, 'the body', error);
    }
    if (json is! Map<String, Object?>) {
      _malformed(path, 'the body of a call is a JSON object');
    }
    try {
      return entry.fromJson(json) as DwServerCall<Object?>;
    } catch (error) {
      // A generated codec reads with casts: a field of the wrong type fails
      // as a TypeError naming the field. Whatever the decoder throws, the
      // body did not describe a ${entry.name}.
      _malformed(path, 'the body is not a ${entry.name}', error);
    }
  }

  /// Rejects the call as malformed: a client bug, answered 400 and logged
  /// with an incident id the client can report — never alerted, and never
  /// with payload in the log.
  Never _malformed(String path, String what, [Object? error]) {
    final incident = DwServerIncident.newId();
    final detail = switch (error) {
      null => '',
      FormatException(:final message) => ': $message',
      _ => ': ${error.runtimeType}',
    };
    _log.warning('malformed call $path: $what$detail (incident $incident)');
    throw _Rejected(
      DwApiResponse.failed(incident, failure: DwFailureKind.malformedCall),
    );
  }

  // --- idempotency --------------------------------------------------------------

  Future<_StoredOutcome?> _storedOutcome(
    DwDatabaseHandle db,
    String key,
    int? accountId,
  ) async {
    final rows = await db.query(
      'SELECT type, status, result FROM dw_command_outcome '
      'WHERE key = @key AND account_id IS NOT DISTINCT FROM @account::int8',
      params: {'key': key, 'account': accountId},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return _StoredOutcome(
      row.get<String>('type'),
      row.get<String>('status'),
      row['result'],
    );
  }

  Future<void> _record(
    DwDatabaseHandle db,
    String key,
    int? accountId,
    String type,
    String status,
    Object? result,
  ) => db.execute(
    'INSERT INTO dw_command_outcome (key, account_id, type, status, result) '
    'VALUES (@key, @account::int8, @type, @status, @result::jsonb) '
    'ON CONFLICT ON CONSTRAINT dw_command_outcome_key DO NOTHING',
    params: {
      'key': key,
      'account': accountId,
      'type': type,
      'status': status,
      'result': result == null ? null : jsonEncode(result),
    },
  );
}

final class _Rejected implements Exception {
  const _Rejected(this.response);

  final DwApiResponse response;
}

final class _StoredOutcome {
  const _StoredOutcome(this.type, this.status, this.result);

  final String type;
  final String status;
  final Object? result;
}

/// The token of an `Authorization: Bearer` header [value], or `null` when
/// there is no header. Anything else — another scheme, no token, two tokens
/// folded into one header by a proxy, a token longer than
/// [DwAuthService.maxTokenLength] — goes to [malformed], which throws.
@internal
String? dwBearerToken(String? value, Never Function(String what) malformed) {
  if (value == null) return null;
  final prefix = DwHttpContract.bearerPrefix;
  // The scheme is case-insensitive (RFC 9110), the token is not.
  if (value.length <= prefix.length ||
      value.substring(0, prefix.length).toLowerCase() != prefix.toLowerCase()) {
    malformed('Authorization is not a Bearer token');
  }
  final token = value.substring(prefix.length);
  if (token.length > DwAuthService.maxTokenLength ||
      !_bearerTokenPattern.hasMatch(token)) {
    malformed('Authorization does not carry one bearer token');
  }
  return token;
}

/// `b64token` of RFC 6750: what a token can be, and not two tokens folded
/// into one header by a proxy.
final RegExp _bearerTokenPattern = RegExp(r'^[A-Za-z0-9\-._~+/]+=*$');
