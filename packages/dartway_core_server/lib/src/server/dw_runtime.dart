import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_alert_sink.dart';
import '../alerts/dw_server_logger.dart';
import '../auth/dw_account_service.dart';
import '../auth/dw_auth_config.dart';
import '../auth/dw_session_cache.dart';
import '../channels/dw_channel_rules.dart';
import '../context/dw_call_context.dart';
import '../files/dw_file_service.dart';
import '../jobs/dw_job_queue.dart';
import '../live/dw_live_connection.dart';
import '../live/dw_live_hub.dart';
import 'dw_server_module.dart';

/// What the running parts of a server share: the database, the live hub, the
/// session cache, the alert gate, and the way contexts are made and their
/// effects delivered.
@internal
final class DwRuntime {
  DwRuntime({
    required this.protocol,
    required this.auth,
    required this.db,
    required this.hub,
    required this.sessions,
    required this.alerts,
    required this.log,
    required this.jobsFor,
    required this.channelRules,
    this.files,
    List<DwServerModule> modules = const [],
  }) : modules = {for (final module in modules) module.runtimeType: module};

  final DwWireProtocol protocol;
  final DwAuthConfig auth;
  final DwDatabaseHandle db;
  final DwLiveHub hub;
  final DwSessionCache sessions;
  final DwAlertGate alerts;
  final DwServerLogger log;
  final DwJobQueue Function(DwRuntimeContext ctx) jobsFor;

  /// Who may read which channel: for subscriptions, and for what a command's
  /// response carries.
  final DwChannelRules channelRules;

  /// The file storage; `null` when the server has none.
  final DwFileStore? files;

  /// The server's modules by their class, for `ctx.module<M>()`.
  final Map<Type, DwServerModule> modules;

  DwRuntimeContext context({
    required String scope,
    required DwContextKind kind,
    DwDatabaseHandle? db,
    DwSessionKeyInfo? sessionKey,
    String? clientAppVersion,
    String? clientUserAgent,
  }) => DwRuntimeContext(
    db: db ?? this.db,
    kind: kind,
    protocol: protocol,
    log: log.scoped(scope),
    jobs: jobsFor,
    accounts: (ctx) => DwAccountService.ofContext(ctx, this),
    files: (ctx) => files?.serviceFor(ctx) ?? const DwUnconfiguredFiles(),
    modules: modules,
    channelRules: channelRules,
    sessionKey: sessionKey,
    clientAppVersion: clientAppVersion,
    clientUserAgent: clientUserAgent,
  );

  /// Delivers the committed effects of [ctx], whose caller hears them over
  /// the socket like every other subscriber: a job, a route, account work, or
  /// a call that did not succeed.
  void deliver(DwRuntimeContext ctx) {
    final effects = ctx.rootEffects;
    if (effects.isEmpty) return;
    _revoke(effects);
    hub.publish(_byChannel(effects.publications));
    effects.clear();
  }

  /// Delivers the committed effects of a successful command of [ctx] and
  /// returns the updates its response carries: the publications to channels
  /// the caller may read (R2.2).
  ///
  /// Revocations go first, so nothing published by the same call reaches a
  /// subscriber whose access it removed. The broadcast follows at once, before
  /// anything is awaited — a later call's publications must not overtake it —
  /// and leaves out [author], the caller's own live connection named in the
  /// call, whose channels the response carries instead: no update reaches the
  /// caller twice.
  ///
  /// The caller may read a channel its connection is subscribed to — access
  /// was checked when it subscribed — and, for every other published channel,
  /// one its rule allows now, asked with the caller's session exactly as a
  /// subscription would be. A channel the call revoked for the caller's
  /// account is not read, nor is anything once the call revoked the caller's
  /// own key. Rules run for accounts only (D-020): an anonymous caller's
  /// response carries none. A rule that throws is reported and read as "no".
  Future<DwUpdateTransport> answer(
    DwRuntimeContext ctx, {
    DwLiveConnection? author,
  }) async {
    final effects = ctx.rootEffects;
    if (effects.isEmpty) return DwUpdateTransport.empty;
    _revoke(effects, author: author);
    final byChannel = _byChannel(effects.publications);
    hub.publish(byChannel, author: author);
    final caller = ctx.sessionKey;
    final revoked = {
      for (final (channel, accountId) in effects.revocations)
        if (accountId == caller?.accountId) channel.wireName,
    };
    final callerSignedOut = effects.revokedKeys.contains(caller?.id);
    effects.clear();
    if (caller == null || callerSignedOut || byChannel.isEmpty) {
      return DwUpdateTransport.empty;
    }

    final readable = <String>{};
    DwRuntimeContext? check;
    for (final name in byChannel.keys) {
      if (revoked.contains(name)) continue;
      if (author?.subscriptions.contains(name) ?? false) {
        readable.add(name);
        continue;
      }
      // `ctx.publish` let only channels with a rule through.
      final known = channelRules.lookUp(name) as DwKnownChannel;
      // One context for every check: rules share its memo.
      check ??= context(
        scope: 'response channels',
        kind: DwContextKind.subscription,
        sessionKey: caller,
      );
      try {
        if (await known.allows(check)) readable.add(name);
      } catch (error, stackTrace) {
        alerts.report(
          where: 'channel rule ${known.rule.kind.channelName} for a response',
          error: error,
          stackTrace: stackTrace,
          accountId: caller.accountId,
        );
      }
    }
    return DwUpdateTransport([
      for (final MapEntry(key: name, value: items) in byChannel.entries)
        if (readable.contains(name))
          for (final (:item, :except) in items)
            if (!except.contains(caller.accountId)) (name, item),
    ]);
  }

  void _revoke(DwCallEffects effects, {DwLiveConnection? author}) {
    for (final keyId in effects.revokedKeys) {
      revokeKey(keyId, author: author);
    }
    for (final (channel, accountId) in effects.revocations) {
      hub.revokeChannel(channel, accountId);
    }
  }

  /// The publications by channel, each object once — at the position of its
  /// last publication, with that publication's exceptions: an object travels
  /// as it ended, so a recipient excluded only from an earlier version does not
  /// receive that stale version instead.
  static Map<String, List<DwPublished>> _byChannel(
    List<(DwLiveChannel, DwWireObject, Set<int>)> publications,
  ) {
    final byChannel = <String, List<DwPublished>>{};
    for (final (channel, item, except) in publications) {
      (byChannel[channel.wireName] ??= []).add((item: item, except: except));
    }
    for (final MapEntry(:key, :value) in byChannel.entries) {
      final last = <(String, Object), int>{};
      for (final (index, published) in value.indexed) {
        last[_keyOf(published.item)] = index;
      }
      if (last.length == value.length) continue;
      byChannel[key] = [
        for (final (index, published) in value.indexed)
          if (last[_keyOf(published.item)] == index) published,
      ];
    }
    return byChannel;
  }

  static (String, Object) _keyOf(DwWireObject item) => switch (item) {
    DwDeletedObject(:final typeName, :final id) => (typeName, id),
    DwDataObject(:final id) => (item.dwTypeName, id),
    // `ctx.publish` lets only these two through.
    _ => throw StateError('not publishable: ${item.dwTypeName}'),
  };

  /// A session key was revoked and the revocation has committed: the next
  /// call with its token reads the database again, and live connections
  /// holding it lose their session.
  void revokeKey(int keyId, {DwLiveConnection? author}) {
    sessions.revoke(keyId);
    hub.revokeKey(keyId, author: author);
  }
}

/// A 32-bit FNV-1a hash of [text], for advisory lock keys. Collisions only
/// serialise unrelated work; they never merge it.
@internal
int dwLockKey(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
    hash ^= unit >> 8;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // Signed int4, the argument type of pg_advisory_xact_lock(int4, int4).
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}

/// Advisory lock namespaces of the framework (first argument of the two-key
/// lock). Projects should keep clear of the 0x4457xxxx range.
@internal
abstract final class DwLockSpace {
  static const int identifier = 0x44570001;
  static const int idempotencyKey = 0x44570002;
  static const int pendingUploads = 0x44570003;
}

/// Whether [error] means "run the transaction again".
@internal
bool dwIsRetryableTransactionError(Object error) =>
    error is DwSerializationFailure ||
    (error is DwDatabaseException && error.code == '40P01');
