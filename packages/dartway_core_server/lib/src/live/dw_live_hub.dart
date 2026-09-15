import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import 'dw_live_connection.dart';

/// The in-process registry of live connections, their sessions and
/// subscriptions, and the place publications fan out. Single isolate by
/// design (D-014): this state exists once.
@internal
final class DwLiveHub {
  final Map<String, DwLiveConnection> _byId = {};
  final Map<String, Set<DwLiveConnection>> _subscribers = {};
  final Map<int, Set<DwLiveConnection>> _byAccount = {};
  final Map<int, Set<DwLiveConnection>> _byKey = {};

  Iterable<DwLiveConnection> get connections => _byId.values;

  void add(DwLiveConnection connection) => _byId[connection.id] = connection;

  /// Forgets a closed connection.
  void remove(DwLiveConnection connection) {
    if (!identical(_byId[connection.id], connection)) return;
    _byId.remove(connection.id);
    for (final name in connection.subscriptions) {
      _removeFrom(_subscribers, name, connection);
    }
    connection.subscriptions.clear();
    _setSession(connection, null);
  }

  /// The open connection a call named in `Dw-Live-Connection`, when it acts
  /// for the same account as the call ([accountId], `null` for anonymous).
  ///
  /// A connection of another account is not the caller's: honouring it would
  /// let one account filter or suppress another's updates, so it is treated
  /// as if no connection had been named.
  DwLiveConnection? connectionOf(String? id, int? accountId) {
    if (id == null) return null;
    final connection = _byId[id];
    if (connection == null ||
        connection.isClosing ||
        connection.accountId != accountId) {
      return null;
    }
    return connection;
  }

  /// Binds [connection] to a session (or to none). Changing the account closes
  /// every subscription: access was checked for the previous one.
  void authenticate(DwLiveConnection connection, DwSessionKeyInfo? sessionKey) {
    if (connection.accountId != sessionKey?.accountId) {
      closeAllSubscriptions(connection);
      connection.authEpoch++;
    }
    _setSession(connection, sessionKey);
  }

  void _setSession(DwLiveConnection connection, DwSessionKeyInfo? sessionKey) {
    if (connection.accountId case final previous?) {
      _removeFrom(_byAccount, previous, connection);
    }
    if (connection.keyId case final previous?) {
      _removeFrom(_byKey, previous, connection);
    }
    connection.sessionKey = sessionKey;
    if (sessionKey != null) {
      (_byAccount[sessionKey.accountId] ??= {}).add(connection);
      (_byKey[sessionKey.id] ??= {}).add(connection);
    }
  }

  void subscribe(DwLiveConnection connection, String wireName) {
    if (connection.subscriptions.add(wireName)) {
      (_subscribers[wireName] ??= {}).add(connection);
    }
  }

  void unsubscribe(DwLiveConnection connection, String wireName) {
    if (connection.subscriptions.remove(wireName)) {
      _removeFrom(_subscribers, wireName, connection);
    }
  }

  /// Closes every subscription of [connection], telling the client.
  void closeAllSubscriptions(DwLiveConnection connection) {
    for (final name in List.of(connection.subscriptions)) {
      unsubscribe(connection, name);
      connection.send(DwChannelClosedMessage(name));
    }
  }

  /// A session key was revoked: every connection holding it loses its
  /// subscriptions and its session, and is told its token was rejected —
  /// except [author], the connection of the caller who signed out, which
  /// asked for it.
  void revokeKey(int keyId, {DwLiveConnection? author}) {
    for (final connection in List.of(_byKey[keyId] ?? const {})) {
      authenticate(connection, null);
      if (!identical(connection, author)) {
        connection.send(const DwAuthenticatedMessage.rejected());
      }
    }
  }

  /// Closes [accountId]'s subscription to [channel], telling its connections.
  void revokeChannel(DwLiveChannel channel, int accountId) {
    final name = channel.wireName;
    for (final connection in List.of(_byAccount[accountId] ?? const {})) {
      if (connection.subscriptions.contains(name)) {
        unsubscribe(connection, name);
        connection.send(DwChannelClosedMessage(name));
      }
    }
  }

  /// Fans publications, grouped by channel wire name, out over the live
  /// sockets: one message per channel, encoded once for all its subscribers;
  /// within a channel an object travels once, as it ended.
  ///
  /// [author] is the caller's own connection when the caller's response
  /// carries the updates: it is left out of the broadcast, and the response
  /// carries — among the rest — every channel it is subscribed to (see
  /// `DwRuntime.answer`). Every other subscriber, the caller's other
  /// connections included, is sent its channels.
  ///
  /// Every object keeps the channel it was published to, on the socket and in
  /// the response (D-036): the client applies it only to the requests that
  /// declare that channel.
  void publish(
    Map<String, List<DwWireObject>> byChannel, {
    DwLiveConnection? author,
  }) {
    for (final MapEntry(key: name, value: items) in byChannel.entries) {
      final subscribers = _subscribers[name];
      if (subscribers == null ||
          (subscribers.length == 1 && identical(subscribers.first, author))) {
        continue;
      }
      final frame = jsonEncode(
        DwUpdateMessage(
          channel: name,
          updates: DwChannelUpdates(items),
        ).toJson(),
      );
      // Iterated in place: `sendFrame` never changes subscriptions
      // synchronously — a slow consumer's close leaves the hub on `done`.
      for (final connection in subscribers) {
        if (!identical(connection, author)) connection.sendFrame(frame);
      }
    }
  }

  static void _removeFrom<K>(
    Map<K, Set<DwLiveConnection>> index,
    K key,
    DwLiveConnection connection,
  ) {
    final set = index[key];
    if (set == null) return;
    set.remove(connection);
    if (set.isEmpty) index.remove(key);
  }
}
