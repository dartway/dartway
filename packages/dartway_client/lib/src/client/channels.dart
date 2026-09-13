part of 'dw_client.dart';

enum _SubState {
  /// Not subscribed on the current connection; subscribes when it can.
  idle,

  /// `sub` sent, answer pending.
  subscribing,

  active,

  /// The server said no. Retried after a reconnect or an account change.
  refused,

  /// The server closed the subscription (access revoked). Not retried for the
  /// same account.
  closed,
}

/// One wire channel and the entries that need it. There is exactly one record
/// per channel name, however many entries declare it: the reference count of
/// SPEC §4 rule 1 is the size of [entries].
final class _ChannelRecord {
  _ChannelRecord(this.name);

  final String name;
  final Set<_Entry> entries = {};
  _SubState state = _SubState.idle;
}

extension on DwClient {
  void _attachChannels(_Entry entry) {
    for (final name in entry.channels) {
      final record = _channels.putIfAbsent(name, () => _ChannelRecord(name));
      record.entries.add(entry);
      if (record.state == _SubState.idle && _ready) {
        record.state = _SubState.subscribing;
        _sendMessage(DwSubscribeMessage(name));
      }
    }
  }

  void _detachChannels(_Entry entry) {
    for (final name in entry.channels) {
      final record = _channels[name];
      if (record == null) continue;
      record.entries.remove(entry);
      if (record.entries.isNotEmpty) continue;
      _channels.remove(name);
      // Subscribing or active means a `sub` went out on this connection; a
      // refused or closed channel holds nothing on the server to release.
      final held =
          record.state == _SubState.subscribing ||
          record.state == _SubState.active;
      if (held && _connection != null) {
        _sendMessage(DwUnsubscribeMessage(name));
      }
    }
  }

  void _onSubscribed(String name) {
    final record = _channels[name];
    // No record: released while the answer travelled, and `unsub` followed.
    if (record == null || record.state != _SubState.subscribing) return;
    record.state = _SubState.active;
    for (final entry in record.entries.toList()) {
      entry.syncLive();
    }
  }

  void _onSubscriptionRefused(DwSubscriptionRefusedMessage message) {
    final name = message.channel;
    final record = _channels[name];
    if (record == null || record.state != _SubState.subscribing) return;
    record.state = _SubState.refused;
    final refusal = message.refusal;
    // A refusal for access is the ordinary answer to a user without it, and
    // the request's own fetch tells that story. An unknown channel is the
    // server never having been taught a kind a request names: a wiring
    // mistake, and silent unless reported. A failed check is an incident the
    // operator was alerted to; reported here too, because the data it leaves
    // behind silently stops being live. Both retry on the next connection or
    // account, as any refusal does.
    if (refusal != null && refusal.isCode(DwCoreRefusal.unknownChannel)) {
      _report(DwChannelRefusedException(name, refusal), StackTrace.current);
    } else if (message.incidentId case final incident?) {
      _report(
        DwFailedException(incident, call: 'subscribe $name'),
        StackTrace.current,
      );
    }
    for (final entry in record.entries.toList()) {
      entry.syncLive();
    }
  }

  void _onChannelClosed(String name) {
    final record = _channels[name];
    if (record == null) return;
    if (_signingOut || _authQueue.isNotEmpty) {
      // Part of an account change the client itself asked for — a server
      // closes every subscription when the account of a connection changes.
      // Once the change completes, what is still needed is subscribed again
      // and every entry re-runs; refetching now would ask twice.
      record.state = _SubState.idle;
      for (final entry in record.entries.toList()) {
        entry.syncLive();
      }
      return;
    }
    record.state = _SubState.closed;
    final entries = record.entries.toList();
    for (final entry in entries) {
      entry.syncLive();
    }
    // Keep the data, stop being live, and ask again so the screen shows what
    // the new access allows — data, or a refusal. Asked on the next turn of
    // the event loop: a server that revokes a whole session closes the
    // channels first and rejects the session right after, and the frames of
    // one burst are read before then. When the account did change, the
    // reconcile has already re-run every entry and asking again would ask
    // twice.
    final account = _connectionAccount;
    final generation = _generation;
    Timer.run(() {
      if (_lifecycle != _Lifecycle.started) return;
      if (_generation != generation || _connectionAccount != account) return;
      for (final entry in entries) {
        if (!entry.disposed) unawaited(entry.refetch());
      }
    });
  }
}
