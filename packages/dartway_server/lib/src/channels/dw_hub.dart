import 'dart:convert';

import 'package:dartway_core/dartway_core.dart';
import 'package:meta/meta.dart';

import '../context/dw_context.dart';
import '../protocol/dw_connection.dart';

/// The in-process registry of connections, sessions and subscriptions, and
/// the place effects are delivered. Single isolate by design (D-014): this
/// state exists once.
@internal
final class DwHub {
  DwHub(this.protocol);

  final DwProtocol protocol;

  final Set<DwConnection> connections = {};
  final Map<String, Set<DwConnection>> _subscribers = {};
  final Map<int, Set<DwConnection>> _byAccount = {};
  final Map<int, Set<DwConnection>> _byKey = {};

  /// Keys revoked recently, by revocation time. Closes the race in which a
  /// connection read a key as valid just before another connection's sign-out
  /// committed, and registers it just after that sign-out was delivered.
  final Map<int, DateTime> _recentlyRevoked = {};
  static const _revocationMemory = Duration(minutes: 2);

  void add(DwConnection connection) => connections.add(connection);

  /// Forgets a closed connection.
  void remove(DwConnection connection) {
    connections.remove(connection);
    for (final name in connection.subscriptions) {
      _removeFrom(_subscribers, name, connection);
    }
    connection.subscriptions.clear();
    _setSession(connection, null, null);
  }

  /// Whether [keyId] was revoked while its lookup may have been in flight.
  bool wasRecentlyRevoked(int keyId) {
    _forgetOldRevocations();
    return _recentlyRevoked.containsKey(keyId);
  }

  void _forgetOldRevocations() {
    final now = DateTime.now();
    _recentlyRevoked.removeWhere(
      (_, at) => now.difference(at) > _revocationMemory,
    );
  }

  /// Binds [connection] to a session (or to none). Changing the account closes
  /// every subscription: access was checked for the previous one.
  void authenticate(DwConnection connection, int? accountId, int? keyId) {
    if (connection.accountId != accountId) {
      closeAllSubscriptions(connection);
      connection.authEpoch++;
    }
    _setSession(connection, accountId, keyId);
  }

  void _setSession(DwConnection connection, int? accountId, int? keyId) {
    if (connection.accountId != null) {
      _removeFrom(_byAccount, connection.accountId!, connection);
    }
    if (connection.keyId != null) {
      _removeFrom(_byKey, connection.keyId!, connection);
    }
    connection
      ..accountId = accountId
      ..keyId = keyId;
    if (accountId != null) {
      (_byAccount[accountId] ??= {}).add(connection);
    }
    if (keyId != null) (_byKey[keyId] ??= {}).add(connection);
  }

  bool subscribe(DwConnection connection, String wireName) {
    if (!connection.subscriptions.add(wireName)) return false;
    (_subscribers[wireName] ??= {}).add(connection);
    return true;
  }

  void unsubscribe(DwConnection connection, String wireName) {
    if (connection.subscriptions.remove(wireName)) {
      _removeFrom(_subscribers, wireName, connection);
    }
  }

  /// Closes every subscription of [connection], telling the client.
  void closeAllSubscriptions(DwConnection connection) {
    for (final name in List.of(connection.subscriptions)) {
      unsubscribe(connection, name);
      connection.send(DwChannelClosedMessage(name));
    }
  }

  /// A session key was revoked: every connection holding it loses its
  /// subscriptions and its session. Connections other than [author] are told
  /// their session was rejected; the author asked for it.
  void revokeKey(int keyId, {DwConnection? author}) {
    _forgetOldRevocations();
    _recentlyRevoked[keyId] = DateTime.now();
    for (final connection in List.of(_byKey[keyId] ?? const <DwConnection>{})) {
      authenticate(connection, null, null);
      if (connection != author) {
        connection.send(const DwAuthenticatedMessage(rejected: true));
      }
    }
  }

  /// Delivers the effects of a committed call. Hooks (key revocations) and
  /// access revocations go first, so nothing published by the same call
  /// reaches a subscriber whose access it removed.
  ///
  /// Publications reach every subscriber, the connection that made the call
  /// included (D-018): a command publishes to channels its client cannot
  /// predict — booking a session also changes the schedule — so without the
  /// echo the author's own screens would be the only stale ones. The client
  /// applies updates idempotently, so an update repeating the command result
  /// changes nothing twice.
  void deliver(DwEffects effects) {
    for (final hook in effects.hooks) {
      hook();
    }
    for (final (channel, accountId) in effects.revocations) {
      final name = channel.wireName;
      for (final connection in List.of(
        _byAccount[accountId] ?? const <DwConnection>{},
      )) {
        if (connection.subscriptions.contains(name)) {
          unsubscribe(connection, name);
          connection.send(DwChannelClosedMessage(name));
        }
      }
    }
    if (effects.publications.isEmpty) return;

    // One message per channel, the latest state of each object once.
    final byChannel = <String, List<DwDto>>{};
    for (final (channel, item) in effects.publications) {
      (byChannel[channel.wireName] ??= []).add(item);
    }
    for (final MapEntry(key: name, value: items) in byChannel.entries) {
      final subscribers = _subscribers[name];
      if (subscribers == null) continue;
      // Encoded once for all subscribers.
      final frame = jsonEncode(
        DwUpdateMessage(
          channel: name,
          items: _latestPerObject(items),
        ).toJson(protocol),
      );
      // Iterated in place: `sendFrame` never changes subscriptions
      // synchronously — a slow consumer's close leaves the hub on `done`.
      for (final connection in subscribers) {
        connection.sendFrame(frame);
      }
    }
  }

  /// Keeps the last publication of each object (by type and id), in the order
  /// of those last publications: an object updated twice and then deleted in
  /// one command travels once, as deleted.
  static List<DwDto> _latestPerObject(List<DwDto> items) {
    if (items.length == 1) return items;
    final seen = <(String, Object)>{};
    final kept = <DwDto>[];
    for (final item in items.reversed) {
      final identity = switch (item) {
        DwDeleted(:final typeName, :final id) => (typeName, id),
        DwDataObject(:final id) => (item.dwTypeName, id),
        _ => null,
      };
      if (identity == null || seen.add(identity)) kept.add(item);
    }
    return kept.reversed.toList();
  }

  static void _removeFrom<K>(
    Map<K, Set<DwConnection>> index,
    K key,
    DwConnection connection,
  ) {
    final set = index[key];
    if (set == null) return;
    set.remove(connection);
    if (set.isEmpty) index.remove(key);
  }
}
