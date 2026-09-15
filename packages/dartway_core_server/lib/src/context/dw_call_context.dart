import 'dart:async';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../auth/dw_account_service.dart';
import '../auth/dw_auth_store.dart';
import '../files/dw_file_service.dart';
import '../jobs/dw_job_queue.dart';
import '../server/dw_server_module.dart';

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

  /// The session key that authenticated this call, or `null` for an
  /// anonymous one: which key it is, its kind and its label.
  ///
  /// The server's own record, never something the client said: this is how a
  /// handler tells a personal key made for a tool
  /// ([DwSessionKeyKind.personal]) from the app. Present on calls, on channel
  /// subscription checks (the key the live socket authenticated with) and on
  /// routes declared with `DwRouteAuth.optional` or `DwRouteAuth.required`;
  /// `null` in jobs. Its `lastUsedAt` is as of when the token was resolved
  /// and may lag by `DwAuthConfig.keyTouchInterval`.
  DwSessionKeyInfo? get sessionKey;

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
  /// channel. The channel travels with the item (D-036): a client applies it
  /// only to requests that declare that channel. A request has no side
  /// effects: publishing from one throws [StateError].
  ///
  /// A "my …" request declares `DwLiveChannel.ofCaller(kind)`; publish to it
  /// by naming whose it is, `DwLiveChannel.forAccount(kind, accountId)`. An
  /// unresolved caller channel throws [ArgumentError]: on a server it could
  /// only mean the caller, and a command changing someone else's data is
  /// exactly where that reading goes wrong.
  void publish(DwLiveChannel channel, DwWireObject item);

  /// Closes [accountId]'s subscriptions to [channel], after commit. Throws
  /// [StateError] in a request, as [publish], and [ArgumentError] for an
  /// unresolved caller channel.
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

  /// Stored files: checking a file id a row references, public URLs in
  /// batch, deleting. Throws [StateError] on use when the server has no file
  /// storage.
  DwFileService get files;

  DwServerLogger get log;

  /// The server's module of class [M] — how a module's context extension
  /// (`ctx.push`) reaches its runtime. Throws [StateError] when the server
  /// was built without one.
  M module<M extends DwServerModule>();

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
    DwFileService Function(DwRuntimeContext ctx)? files,
    Map<Type, DwServerModule> modules = const {},
    this.sessionKey,
    String? clientAppVersion,
    String? clientUserAgent,
  }) : _root = _Scope(db),
       _jobs = jobs,
       _accounts = accounts,
       _clientAppVersion = clientAppVersion,
       _clientUserAgent = clientUserAgent,
       _modules = modules,
       _files = files ?? ((_) => const DwUnconfiguredFiles());

  final _Scope _root;
  final Object _zoneKey = Object();
  final Map<Object, Object?> _memo = {};
  final DwJobQueue Function(DwRuntimeContext ctx) _jobs;
  final DwAccountService Function(DwRuntimeContext ctx) _accounts;
  final DwFileService Function(DwRuntimeContext ctx) _files;
  final Map<Type, DwServerModule> _modules;

  final DwContextKind kind;

  @override
  final DwSessionKeyInfo? sessionKey;

  @override
  int? get accountId => sessionKey?.accountId;

  final String? _clientAppVersion;
  final String? _clientUserAgent;

  /// What the calling app said about itself, as the label of a key a sign-in
  /// makes (`DwAuthStore.appLabel`); empty outside commands. Built on first
  /// use: only a sign-in reads it.
  late final String clientLabel = DwAuthStore.appLabel(
    appVersion: _clientAppVersion,
    userAgent: _clientUserAgent,
  );

  /// Whether the call made a secret its result may carry — a session key's
  /// token (`DwAccountService.issueKey`). A command that did never stores its
  /// successful outcome for idempotency: the outcome table must not hold a
  /// token, so a retried send runs again instead of replaying.
  bool get madeSecret => _madeSecret;
  bool _madeSecret = false;

  void markSecret() => _madeSecret = true;

  @override
  final DwWireProtocol protocol;

  @override
  final DwServerLogger log;

  // Both built on first use: most calls touch neither.
  @override
  late final DwJobQueue jobs = _jobs(this);

  @override
  late final DwAccountService accounts = _accounts(this);

  @override
  late final DwFileService files = _files(this);

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
    _requireResolved(channel);
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
    _requireResolved(channel);
    _current.effects.revocations.add((channel, accountId));
  }

  static void _requireResolved(DwLiveChannel channel) {
    if (channel.isOfCaller) {
      throw ArgumentError.value(
        channel,
        'channel',
        'A caller channel is resolved by the client for whoever watches. '
            'Name the account: DwLiveChannel.forAccount('
            '${channel.kind.channelName}, accountId)',
      );
    }
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
  M module<M extends DwServerModule>() {
    final exact = _modules[M];
    if (exact != null) return exact as M;
    for (final module in _modules.values) {
      if (module is M) return module;
    }
    throw StateError(
      'This server has no $M: pass it in DwAppServer(modules: [...]).',
    );
  }

  @override
  T memo<T>(Object key, T Function() create) {
    if (_memo.containsKey(key)) return _memo[key] as T;
    final value = create();
    _memo[key] = value;
    return value;
  }
}
