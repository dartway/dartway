import 'dart:async';

import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_logger.dart';
import '../handlers/dw_handler.dart';
import '../jobs/dw_jobs.dart';
import '../protocol/dw_connection.dart';

/// Everything a handler may touch. One per call; projects add their own
/// notions by extension, cached with [memo]:
///
/// ```dart
/// extension AppContext on DwContext {
///   Future<UserProfile> get profile => memo(#profile, () => …);
/// }
/// ```
abstract class DwContext {
  /// The signed-in account of the connection, or `null`.
  int? get accountId;

  /// The signed-in account; throws [DwNotAuthenticatedException] (answered as
  /// `DwNotAuthenticated`) when there is none.
  int get requireAccountId;

  /// The database. Inside a transactional command, and inside the body of
  /// [transaction], this is the transaction.
  DwDb get db;

  /// The protocol both sides speak (for `DwDeleted.of<T>(id, ctx.protocol)`).
  DwProtocol get protocol;

  /// Runs [body] in a transaction (a savepoint when already inside one).
  /// Publications, revocations and jobs made inside it take effect only when
  /// it commits.
  Future<T> transaction<T>(Future<T> Function(DwDb tx) body);

  /// Sends [item] (a data object or a `DwDeleted`) to the subscribers of
  /// [channel] once the enclosing transaction commits (or when the call ends,
  /// outside a transaction). Batched per channel into one message per
  /// connection; the connection that made the call does not receive it.
  void publish(DwChannel channel, DwDto item);

  /// Closes [accountId]'s subscriptions to [channel], after commit.
  void revoke(DwChannel channel, int accountId);

  /// Refuses the call.
  Never refuse(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    String? field,
  });

  /// Background jobs; an enqueue joins the enclosing transaction.
  DwJobs get jobs;

  DwLogger get log;

  /// A per-call cache: [create] runs at most once per [key] per call.
  T memo<T>(Object key, T Function() create);
}

/// What a call changes outside the database: delivered only after the
/// transaction it was made in commits, discarded if it rolls back.
@internal
final class DwEffects {
  final List<(DwChannel, DwDto)> publications = [];
  final List<(DwChannel, int)> revocations = [];

  /// Framework hooks (a revoked session key) run with the rest.
  final List<void Function()> hooks = [];

  bool get isEmpty =>
      publications.isEmpty && revocations.isEmpty && hooks.isEmpty;

  void absorb(DwEffects other) {
    publications.addAll(other.publications);
    revocations.addAll(other.revocations);
    hooks.addAll(other.hooks);
  }

  void clear() {
    publications.clear();
    revocations.clear();
    hooks.clear();
  }
}

final class _Scope {
  _Scope(this.db);

  final DwDb db;
  final DwEffects effects = DwEffects();
}

/// The one context implementation: for calls on a connection, for jobs and for
/// web routes (the latter two have no account and no author connection).
@internal
final class DwCallContext extends DwContext {
  DwCallContext({
    required DwDb db,
    required this.protocol,
    required this.log,
    required DwJobs Function(DwCallContext ctx) jobs,
    required bool Function(Object item) isPublishable,
    this.accountId,
    this.keyId,
    this.connection,
  }) : _root = _Scope(db),
       _isPublishable = isPublishable {
    this.jobs = jobs(this);
  }

  final _Scope _root;
  final Object _zoneKey = Object();
  final Map<Object, Object?> _memo = {};
  final bool Function(Object item) _isPublishable;

  @override
  final int? accountId;

  /// The session key the connection authenticated with, for sign-out.
  final int? keyId;

  /// The connection that made the call; `null` for jobs and routes. Its
  /// subscriptions do not receive what this call publishes.
  final DwConnection? connection;

  @override
  final DwProtocol protocol;

  @override
  final DwLogger log;

  @override
  late final DwJobs jobs;

  _Scope get _current => (Zone.current[_zoneKey] as _Scope?) ?? _root;

  /// Effects that are due once the call ends.
  DwEffects get rootEffects => _root.effects;

  @override
  int get requireAccountId =>
      accountId ?? (throw const DwNotAuthenticatedException());

  @override
  DwDb get db => _current.db;

  @override
  Future<T> transaction<T>(Future<T> Function(DwDb tx) body) async {
    final parent = _current;
    late _Scope scope;
    final result = await parent.db.transaction((tx) {
      scope = _Scope(tx);
      return runZoned(() => body(tx), zoneValues: {_zoneKey: scope});
    });
    // Reached only when the transaction (or savepoint) committed: its effects
    // now belong to the parent, and ride on the parent's commit in turn.
    parent.effects.absorb(scope.effects);
    return result;
  }

  /// Runs [body] as the call's own transaction; used for transactional
  /// commands. On success the effects join the root.
  Future<T> runTransactional<T>(Future<T> Function() body) =>
      transaction((_) => body());

  /// Forgets per-call state before a transaction is retried.
  void resetForRetry() {
    _memo.clear();
    _root.effects.clear();
  }

  @override
  void publish(DwChannel channel, DwDto item) {
    if (item is! DwDataObject && item is! DwDeleted) {
      throw ArgumentError.value(
        item.runtimeType,
        'item',
        'Only data objects and DwDeleted notices travel on channels',
      );
    }
    if (!_isPublishable(item)) {
      throw ArgumentError.value(
        item.runtimeType,
        'item',
        'Not registered in the protocol',
      );
    }
    _current.effects.publications.add((channel, item));
  }

  @override
  void revoke(DwChannel channel, int accountId) {
    _current.effects.revocations.add((channel, accountId));
  }

  /// Registers a framework hook to run with the other effects.
  void afterCommit(void Function() hook) {
    _current.effects.hooks.add(hook);
  }

  @override
  Never refuse(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    String? field,
  }) => throw DwRefusalException(DwRefusal(code, params: params, field: field));

  @override
  T memo<T>(Object key, T Function() create) {
    if (_memo.containsKey(key)) return _memo[key] as T;
    final value = create();
    _memo[key] = value;
    return value;
  }
}
