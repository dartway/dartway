import 'dart:convert';

import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_logger.dart';
import '../context/dw_context.dart';
import '../handlers/dw_handler.dart';
import '../protocol/dw_connection.dart';
import 'dw_runtime.dart';

/// A request the wire allows but the call cannot mean: page parameters on a
/// list request, an oversized idempotency key. Only a broken client sends
/// one, so it is a failure (alerted), not a refusal.
@internal
final class DwProtocolViolation implements Exception {
  DwProtocolViolation(this.message);

  final String message;

  @override
  String toString() => 'DwProtocolViolation: $message';
}

/// Runs requests and commands: access, validation, the handler, idempotency,
/// and the mapping of every outcome onto a result message.
@internal
final class DwDispatcher {
  DwDispatcher(this.runtime, this.handlers);

  final DwRuntime runtime;
  final Map<Type, DwHandler> handlers;

  static const int _maxTransactionAttempts = 3;
  static const int maxIdempotencyKeyLength = 128;

  Future<DwResultMessage> runRequest(
    DwConnection connection,
    DwRequestMessage message,
  ) async {
    final request = message.request;
    final where = 'request ${request.dwTypeName}';
    final ctx = runtime.context(
      scope: '$where #${message.id}',
      accountId: connection.accountId,
      keyId: connection.keyId,
      connection: connection,
    );
    try {
      final handler = handlers[request.runtimeType];
      if (handler == null) {
        throw StateError('No handler is registered for $where');
      }
      _requireSignIn(handler.access, ctx);
      _validate(request);
      await _check(handler.access, ctx);
      final Object? value = switch (handler) {
        DwRequestHandler() => await () {
          if (message.page != null) {
            throw DwProtocolViolation('page parameters on a non-paged $where');
          }
          return handler.run(ctx, request);
        }(),
        DwPageHandler() => await handler.run(
          ctx,
          request,
          _pageInput(request, message.page, where),
        ),
        DwCommandHandler() => throw StateError('$where has a command handler'),
      };
      return DwResultMessage(
        id: message.id,
        status: DwResultStatus.ok,
        value: value,
      );
    } catch (error, stackTrace) {
      return _answerError(message.id, where, error, stackTrace, ctx);
    } finally {
      runtime.deliver(ctx);
    }
  }

  Future<DwResultMessage> runCommand(
    DwConnection connection,
    DwCommandMessage message,
  ) async {
    final command = message.command;
    final key = message.idempotencyKey;
    final typeName = command.dwTypeName;
    final where = 'command $typeName';
    final accountId = connection.accountId;
    final ctx = runtime.context(
      scope: '$where #${message.id}',
      accountId: accountId,
      keyId: connection.keyId,
      connection: connection,
    );
    final id = message.id;
    try {
      if (key.isEmpty || key.length > maxIdempotencyKeyLength) {
        throw DwProtocolViolation(
          'idempotency key of ${key.length} characters on $where',
        );
      }
      final handler = handlers[command.runtimeType];
      if (handler is! DwCommandHandler) {
        throw StateError('No handler is registered for $where');
      }

      // A transactional command looks its key up inside its transaction, under
      // the key's lock; looking here as well would cost every first send a
      // round trip.
      if (!handler.transactional) {
        final stored = await _storedOutcome(runtime.db, key, accountId);
        if (stored != null) return _replay(id, stored, typeName);
      }

      _requireSignIn(handler.access, ctx);
      try {
        _validate(command);
        final Object? value;
        if (handler.transactional) {
          final outcome = await _runTransactional(
            ctx,
            handler,
            command,
            key,
            accountId,
          );
          if (outcome.stored != null) {
            return _replay(id, outcome.stored!, typeName);
          }
          value = outcome.value;
        } else {
          await _check(handler.access, ctx);
          value = await handler.run(ctx, command);
          if (handler.recordsSuccess) {
            await _record(runtime.db, key, accountId, typeName, 'ok', value);
          }
        }
        return DwResultMessage(id: id, status: DwResultStatus.ok, value: value);
      } on DwRefusalException catch (refusal) {
        // The transaction has rolled back; the refusal is the outcome.
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
    } catch (error, stackTrace) {
      return _answerError(id, where, error, stackTrace, ctx);
    } finally {
      runtime.deliver(ctx);
    }
  }

  Future<({Object? value, _StoredOutcome? stored})> _runTransactional(
    DwCallContext ctx,
    DwCommandHandler handler,
    DwCommand<Object?> command,
    String key,
    int? accountId,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await ctx.runTransactional(() async {
          // Two sends of one key racing each other: the second waits here and
          // then finds the first one's outcome.
          await ctx.db.advisoryLock(
            DwLockSpace.idempotencyKey,
            dwLockKey('$accountId/$key'),
          );
          final stored = await _storedOutcome(ctx.db, key, accountId);
          if (stored != null) return (value: null, stored: stored);
          await _check(handler.access, ctx);
          final value = await handler.run(ctx, command);
          if (handler.recordsSuccess) {
            await _record(
              ctx.db,
              key,
              accountId,
              command.dwTypeName,
              'ok',
              value,
            );
          }
          return (value: value, stored: null);
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
  }

  void _requireSignIn(DwAccess access, DwContext ctx) {
    if (access is! DwAnonymousAccess && ctx.accountId == null) {
      throw const DwNotAuthenticatedException();
    }
  }

  Future<void> _check(DwAccess access, DwContext ctx) async {
    if (access is DwCheckAccess && !await access.check(ctx)) {
      ctx.refuse(DwCoreRefusal.forbidden);
    }
  }

  /// The client ran the same check before sending; running it again is what
  /// makes it a rule rather than a courtesy of well-behaved clients.
  void _validate(DwDto dto) {
    if (dto case final DwValidatable validatable) {
      final refusals = validatable.validate();
      if (refusals.isNotEmpty) throw DwRefusalException(refusals.first);
    }
  }

  DwPageInput _pageInput(
    DwRequest<Object?> request,
    DwPageParams? params,
    String where,
  ) {
    final pageSize = dwPageSizeOf(request);
    if (pageSize == null || pageSize < 1) {
      throw StateError('$where has no valid pageSize ($pageSize)');
    }
    switch ((request, params)) {
      case (DwPageRequest(), null):
        return dwPageInput(pageSize: pageSize, offset: 0, before: null);
      case (DwPageRequest(), DwOffsetParams(:final offset)) when offset >= 0:
        return dwPageInput(pageSize: pageSize, offset: offset, before: null);
      case (DwCursorRequest(), null):
        return dwPageInput(pageSize: pageSize, offset: 0, before: null);
      case (DwCursorRequest(), DwCursorParams(:final before))
          when before == null || before is int || before is String:
        return dwPageInput(pageSize: pageSize, offset: 0, before: before);
      default:
        throw DwProtocolViolation('page parameters do not fit $where');
    }
  }

  DwResultMessage _replay(int id, _StoredOutcome stored, String typeName) {
    if (stored.type != typeName) {
      // One key, two intents: a client bug that must not execute either way.
      return DwResultMessage(
        id: id,
        status: DwResultStatus.refused,
        refusal: DwRefusal(
          DwCoreRefusal.conflict,
          params: {'idempotencyKey': 'reused'},
        ),
      );
    }
    return stored.status == 'ok'
        ? DwResultMessage(
            id: id,
            status: DwResultStatus.ok,
            value: stored.result,
          )
        : DwResultMessage(
            id: id,
            status: DwResultStatus.refused,
            refusal: DwRefusal.fromJson(stored.result! as Map<String, Object?>),
          );
  }

  DwResultMessage _answerError(
    int id,
    String where,
    Object error,
    StackTrace stackTrace,
    DwContext ctx,
  ) {
    switch (error) {
      case DwRefusalException(:final refusal):
        return DwResultMessage(
          id: id,
          status: DwResultStatus.refused,
          refusal: refusal,
        );
      case DwNotAuthenticatedException():
        return DwResultMessage(id: id, status: DwResultStatus.unauthenticated);
      default:
        final incidentId = runtime.alerts.report(
          where: where,
          error: error,
          stackTrace: stackTrace,
          accountId: ctx.accountId,
        );
        return DwResultMessage(
          id: id,
          status: DwResultStatus.failed,
          incidentId: incidentId,
        );
    }
  }

  Future<_StoredOutcome?> _storedOutcome(
    DwDb db,
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
    DwDb db,
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

final class _StoredOutcome {
  const _StoredOutcome(this.type, this.status, this.result);

  final String type;
  final String status;
  final Object? result;
}
