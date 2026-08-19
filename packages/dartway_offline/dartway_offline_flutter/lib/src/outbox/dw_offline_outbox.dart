import 'dart:convert';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/drift.dart';

import '../storage/dw_offline_database.dart';

enum DwOutboxReplayStatus {
  accepted,
  rejected,
  conflict,
  connectionFailure,
  corrupt,
}

final class DwOutboxReplayResult {
  const DwOutboxReplayResult._(this.status, {this.responseJson});

  const DwOutboxReplayResult.accepted({Map<String, dynamic>? responseJson})
    : this._(DwOutboxReplayStatus.accepted, responseJson: responseJson);

  const DwOutboxReplayResult.rejected({Map<String, dynamic>? responseJson})
    : this._(DwOutboxReplayStatus.rejected, responseJson: responseJson);

  const DwOutboxReplayResult.conflict({Map<String, dynamic>? responseJson})
    : this._(DwOutboxReplayStatus.conflict, responseJson: responseJson);

  const DwOutboxReplayResult.connectionFailure()
    : this._(DwOutboxReplayStatus.connectionFailure);

  const DwOutboxReplayResult.corrupt() : this._(DwOutboxReplayStatus.corrupt);

  final DwOutboxReplayStatus status;
  final Map<String, dynamic>? responseJson;
}

typedef DwOutboxReplayTransport =
    Future<DwOutboxReplayResult> Function(DwRepoMutation mutation);

/// Replays one user scope in stable queue order through an app-owned endpoint.
final class DwOfflineOutbox {
  DwOfflineOutbox(this._database);

  final DwOfflineDatabase _database;
  Future<void> _operationTail = Future<void>.value();

  Stream<List<DwRepoMutation>> watchPendingMutations(String userScopeId) {
    _validateUserScopeId(userScopeId);
    final query = _database.select(_database.dwOfflineOutbox)
      ..where((row) => row.userScopeId.equals(userScopeId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAtEpochMs),
        (row) => OrderingTerm.asc(row.updatedAtEpochMs),
      ]);
    return query.watch().map((rows) {
      return rows
          .map((row) {
            final mutation = _decodeMutation(row, userScopeId);
            if (mutation == null) {
              throw StateError('Stored offline mutation is corrupt.');
            }
            return mutation;
          })
          .toList(growable: false);
    });
  }

  Future<List<DwOutboxReplayResult>> replay({
    required String userScopeId,
    required DwOutboxReplayTransport transport,
  }) {
    _validateUserScopeId(userScopeId);
    return _serialize(() async {
      final rows =
          await (_database.select(_database.dwOfflineOutbox)
                ..where((row) => row.userScopeId.equals(userScopeId))
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAtEpochMs),
                  (row) => OrderingTerm.asc(row.updatedAtEpochMs),
                ]))
              .get();
      final outcomes = <DwOutboxReplayResult>[];
      for (final row in rows) {
        final mutation = _decodeMutation(row, userScopeId);
        if (mutation == null) {
          outcomes.add(const DwOutboxReplayResult.corrupt());
          break;
        }
        DwOutboxReplayResult outcome;
        try {
          outcome = await transport(mutation);
        } on Object catch (error) {
          if (!isStreamingConnectionError(error)) rethrow;
          outcome = const DwOutboxReplayResult.connectionFailure();
        }
        outcomes.add(outcome);
        if (outcome.status == DwOutboxReplayStatus.connectionFailure ||
            outcome.status == DwOutboxReplayStatus.corrupt) {
          break;
        }
        await (_database.delete(_database.dwOfflineOutbox)..where(
              (queuedRow) =>
                  queuedRow.userScopeId.equals(userScopeId) &
                  queuedRow.mutationId.equals(row.mutationId),
            ))
            .go();
      }
      return outcomes;
    });
  }

  static void _validateUserScopeId(String userScopeId) {
    if (userScopeId.trim().isEmpty || userScopeId != userScopeId.trim()) {
      throw ArgumentError.value(userScopeId, 'userScopeId');
    }
  }

  static DwRepoMutation? _decodeMutation(
    DwOfflineOutboxRow row,
    String userScopeId,
  ) {
    try {
      final decoded = jsonDecode(row.envelopeJson);
      if (decoded is! Map) return null;
      final mutation = DwRepoMutation.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (mutation.scope.storageKey != userScopeId ||
          mutation.mutationId != row.mutationId ||
          mutation.idempotencyKey != row.idempotencyKey ||
          mutation.operation.name != row.mutationType ||
          mutation.entityType != row.entityType) {
        return null;
      }
      return mutation;
    } on Object {
      return null;
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final queued = _operationTail.then((_) => operation());
    _operationTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}
