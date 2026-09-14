import 'dart:collection';

import 'package:meta/meta.dart';

/// A session a token resolved to.
@internal
typedef DwResolvedSession = ({int accountId, int keyId});

/// Tokens already resolved to sessions, so that a call — every call is an
/// HTTP request now — authenticates without a query in the common case.
///
/// Keyed by the token's hash, never the token: the cache outlives the request
/// that brought the token, and a heap dump must not sign anyone in.
///
/// Bounded twice: at most [capacity] entries (the least recently used goes
/// first), each trusted for [ttl]. A revocation made by this process removes
/// its key at once ([revoke]); [ttl] bounds how late a revocation made
/// elsewhere is noticed.
@internal
final class DwSessionCache {
  DwSessionCache({
    required this.capacity,
    required this.ttl,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int capacity;
  final Duration ttl;
  final DateTime Function() _clock;

  final LinkedHashMap<String, DwCachedSession> _entries = LinkedHashMap();
  final Map<int, String> _hashOfKey = {};

  /// Keys revoked recently, by revocation time. Closes the race in which a
  /// lookup read a key as valid just before its revocation committed and
  /// finishes just after the revocation was delivered: without it, the stale
  /// answer would be cached for a whole [ttl].
  final Map<int, DateTime> _recentlyRevoked = {};
  static const _revocationMemory = Duration(minutes: 2);

  DateTime get now => _clock();

  /// The live entry for [hash], or `null`. A hit becomes the most recently
  /// used.
  DwCachedSession? lookup(String hash) {
    final entry = _entries.remove(hash);
    if (entry == null) return null;
    if (!now.isBefore(entry.expiresAt)) {
      _hashOfKey.remove(entry.session.keyId);
      return null;
    }
    _entries[hash] = entry;
    return entry;
  }

  /// Remembers a session read from the database, unless its key was revoked
  /// while the read was in flight — then returns `false`, and the session
  /// must not be used either.
  bool store(String hash, DwResolvedSession session, DateTime touchedAt) {
    if (wasRecentlyRevoked(session.keyId)) return false;
    if (capacity == 0) return true;
    _entries.remove(hash);
    if (_entries.length >= capacity) {
      final oldest = _entries.keys.first;
      final evicted = _entries.remove(oldest)!;
      _hashOfKey.remove(evicted.session.keyId);
    }
    _entries[hash] = DwCachedSession(session, now.add(ttl), touchedAt);
    _hashOfKey[session.keyId] = hash;
    return true;
  }

  /// Forgets [keyId] now and refuses to cache it for a while.
  void revoke(int keyId) {
    _forgetOldRevocations();
    _recentlyRevoked[keyId] = now;
    final hash = _hashOfKey.remove(keyId);
    if (hash != null) _entries.remove(hash);
  }

  bool wasRecentlyRevoked(int keyId) {
    _forgetOldRevocations();
    return _recentlyRevoked.containsKey(keyId);
  }

  void _forgetOldRevocations() {
    if (_recentlyRevoked.isEmpty) return;
    final current = now;
    _recentlyRevoked.removeWhere(
      (_, at) => current.difference(at) > _revocationMemory,
    );
  }

  int get length => _entries.length;
}

@internal
final class DwCachedSession {
  DwCachedSession(this.session, this.expiresAt, this.touchedAt);

  final DwResolvedSession session;
  final DateTime expiresAt;

  /// When `last_used_at` was last written, as far as this process knows.
  DateTime touchedAt;
}
