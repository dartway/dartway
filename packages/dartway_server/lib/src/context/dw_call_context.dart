import 'dart:async';

import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../auth/dw_account_service.dart';
import '../jobs/dw_job_queue.dart';

/// Thrown when a call needs a signed-in account and has none. The framework
/// answers `unauthenticated` (HTTP 401).
final class DwNotAuthenticatedException implements Exception {
  const DwNotAuthenticatedException();

  @override
  String toString() => 'DwNotAuthenticatedException';
}

/// Everything a handler may touch. One per call; projects add their own
/// notions by extension, cached with [memo]:
///
/// ```dart
/// extension AppCallContext on DwCallContext {
///   Future<UserProfile> get profile => memo(#profile, () => …);
/// }
/// ```
abstract class DwCallContext {
  /// The signed-in account of the caller, or `null`.
  int? get accountId;

  /// The signed-in account; throws [DwNotAuthenticatedException] (answered as
  /// `unauthenticated`) when there is none.
  int get requireAccountId;

  /// The database. Inside a transactional command, and inside the body of
  /// [transaction], this is the transaction.
  DwDatabaseHandle get db;

  /// The protocol both sides speak (for
  /// `DwDeletedObject.of<T>(id, ctx.protocol)`).
  DwWireProtocol get protocol;

  /// Runs [body] in a transaction (a savepoint when already inside one).
  /// Publications, revocations and jobs made inside it take effect only when
  /// it commits.
  Future<T> transaction<T>(Future<T> Function(DwDatabaseHandle tx) body);

  /// Sends [item] (a data object or a `DwDeletedObject`) to [channel] once
  /// the enclosing transaction commits (or when the call ends, outside a
  /// transaction).
  ///
  /// A command's publications are answered in its response to the caller and
  /// sent over the live socket to every other subscriber, one message per
  /// channel. A request has no side effects: publishing from one throws
  /// [StateError].
  void publish(DwLiveChannel channel, DwWireObject item);

  /// Closes [accountId]'s subscriptions to [channel], after commit. Throws
  /// [StateError] in a request, as [publish].
  void revoke(DwLiveChannel channel, int accountId);

  /// Refuses the call.
  Never refuse(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    String? field,
  });

  /// Background jobs; an enqueue joins the enclosing transaction.
  DwJobQueue get jobs;

  /// Accounts by identifier, bound to this context: writes join its
  /// transaction, and revoked sessions close after it commits.
  DwAccountService get accounts;

  DwServerLogger get log;

  /// A per-call cache: [create] runs at most once per [key] per call.
  T memo<T>(Object key, T Function() create);
}

/// What runs in a context, which decides what the context allows.
@internal
enum DwContextKind {
  /// A read: no publications, no revocations.
  request,

  /// A change, with a response that carries its publications.
  command,

  /// A channel subscription check: a read, like a request.
  subscription,

  /// A background job, a project route or server-level account work.
  background;

  bool get mayPublish => this == command || this == background;
}

/// What a call changes outside the database: delivered only after the
/// transaction it was made in commits, discarded if it rolls back.
@internal
final class DwCallEffects {
  final List<(DwLiveChannel, DwWireObject)> publications = [];
  final List<(DwLiveChannel, int)> revocations = [];

  /// Session keys revoked by the call.
  final List<int> revokedKeys = [];

  bool get isEmpty =>
      publications.isEmpty && revocations.isEmpty && revokedKeys.isEmpty;

  void absorb(DwCallEffects other) {
    publications.addAll(other.publications);
    revocations.addAll(other.revocations);
    revokedKeys.addAll(other.revokedKeys);
  }

  void clear() {
    publications.clear();
    revocations.clear();
    revokedKeys.clear();
  }
}

final class _Scope {
  _Scope(this.db);

  final DwDatabaseHandle db;
  final DwCallEffects effects = DwCallEffects();
}

/// The one context implementation: for calls, subscription checks, jobs,
/// routes and server-level account work.
@internal
final class DwRuntimeContext extends DwCallContext {
  DwRuntimeContext({
    required DwDatabaseHandle db,
    required this.kind,
    required this.protocol,
    required this.log,
    required DwJobQueue Function(DwRuntimeContext ctx) jobs,
    required DwAccountService Function(DwRuntimeContext ctx) accounts,
    this.accountId,
    this.keyId,
  }) : _root = _Scope(db),
       _jobs = jobs,
       _accounts = accounts;

  final _Scope _root;
  final Object _zoneKey = Object();
  final Map<Object, Object?> _memo = {};
  final DwJobQueue Function(DwRuntimeContext ctx) _jobs;
  final DwAccountService Function(DwRuntimeContext ctx) _accounts;

  final DwContextKind kind;

  @override
  final int? accountId;

  /// The session key the caller authenticated with, for sign-out.
  final int? keyId;

  @override
  final DwWireProtocol protocol;

  @override
  final DwServerLogger log;

  // Both built on first use: most calls touch neither.
  @override
  late final DwJobQueue jobs = _jobs(this);

  @override
  late final DwAccountService accounts = _accounts(this);

  _Scope get _current => (Zone.current[_zoneKey] as _Scope?) ?? _root;

  /// Effects that are due once the call ends.
  DwCallEffects get rootEffects => _root.effects;

  @override
  int get requireAccountId =>
      accountId ?? (throw const DwNotAuthenticatedException());

  @override
  DwDatabaseHandle get db => _current.db;

  @override
  Future<T> transaction<T>(Future<T> Function(DwDatabaseHandle tx) body) async {
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

  /// Forgets per-call state before a transaction is retried.
  void resetForRetry() {
    _memo.clear();
    _root.effects.clear();
  }

  @override
  void publish(DwLiveChannel channel, DwWireObject item) {
    requireSideEffects('publish');
    if (item is! DwDataObject && item is! DwDeletedObject) {
      throw ArgumentError.value(
        item.runtimeType,
        'item',
        'Only data objects and DwDeletedObject notices travel on channels',
      );
    }
    if (!protocol.knows(item.runtimeType)) {
      throw ArgumentError.value(
        item.runtimeType,
        'item',
        'Not registered in the protocol',
      );
    }
    if (item case DwDeletedObject(
      :final typeName,
    ) when protocol.entryNamed(typeName)?.kind != DwWireObjectKind.dataObject) {
      // A client cannot decode a transport that deletes an unknown type; the
      // mistake is the publisher's, and is reported where it is made.
      throw ArgumentError.value(
        typeName,
        'item',
        'A deletion names a data object type of the protocol',
      );
    }
    _current.effects.publications.add((channel, item));
  }

  @override
  void revoke(DwLiveChannel channel, int accountId) {
    requireSideEffects('revoke');
    _current.effects.revocations.add((channel, accountId));
  }

  /// Records a revoked session key, delivered with the other effects.
  void revokedKey(int keyId) {
    requireSideEffects('revokeKeys');
    _current.effects.revokedKeys.add(keyId);
  }

  /// Throws [StateError] unless this context may change things outside the
  /// database: a read that did would change them for every retry and cache
  /// of it, and its effects would never be delivered.
  void requireSideEffects(String what) {
    if (!kind.mayPublish) {
      throw StateError(
        '$what in a ${kind.name}: reads have no side effects, so a client may '
        'retry and cache them. Publish from a command.',
      );
    }
  }

  @override
  Never refuse(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    String? field,
  }) => throw DwRefusalException(
    DwCallRefusal(code, params: params, field: field),
  );

  @override
  T memo<T>(Object key, T Function() create) {
    if (_memo.containsKey(key)) return _memo[key] as T;
    final value = create();
    _memo[key] = value;
    return value;
  }
}
