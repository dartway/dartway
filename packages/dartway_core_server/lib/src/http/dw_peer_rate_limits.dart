import 'dart:io';

import 'package:meta/meta.dart';

import '../server/dw_server_settings.dart';
import 'dw_call_rate_limit.dart';

/// HTTP-only state; the call context never receives forwarding headers.
@internal
final class DwPeerRateLimits {
  DwPeerRateLimits(DwServerSettings settings)
    : _networks = settings.trustedProxyNetworks
          .map(_ProxyNetwork.parse)
          .toList(),
      _quotas = {
        for (final entry in settings.callRateLimits.entries)
          entry.key: _PeerQuota(entry.value),
      };

  final List<_ProxyNetwork> _networks;
  final Map<Type, _PeerQuota> _quotas;

  static List<String> problems(DwServerSettings settings) {
    final problems = <String>[
      if (settings.behindProxy &&
          settings.callRateLimits.isNotEmpty &&
          settings.trustedProxyNetworks.isEmpty)
        'peer quotas behind a proxy require trustedProxyNetworks',
      for (final entry in settings.callRateLimits.entries)
        for (final problem in entry.value.problems)
          'call rate limit for ${entry.key}: $problem',
    ];
    for (final network in settings.trustedProxyNetworks) {
      try {
        _ProxyNetwork.parse(network);
      } on FormatException {
        problems.add(
          'trusted proxy network "$network" must be an IPv4/IPv6 '
          'CIDR with a nonzero prefix',
        );
      }
    }
    return problems;
  }

  Duration? check(Type callType, HttpRequest request, DateTime now) {
    final quota = _quotas[callType];
    if (quota == null) return null;
    final peer = peerKey(request);
    if (peer == null) return const Duration(seconds: 1);
    return quota.charge(peer, now);
  }

  /// Resolves the caller through the same trusted-proxy boundary as quotas.
  String? peerKey(HttpRequest request) {
    final transport = request.connectionInfo?.remoteAddress;
    // Missing transport metadata must not open a quota bypass.
    if (transport == null) return null;
    var peer = _bytes(transport);
    if (_trusted(peer)) {
      final chain = request.headers['x-forwarded-for']?.join(',').split(',');
      if (chain != null) {
        for (final value in chain.reversed) {
          if (!_trusted(peer)) break;
          final address = InternetAddress.tryParse(value.trim());
          if (address == null) {
            // An invalid chain is one transport peer, never an arbitrary key.
            peer = _bytes(transport);
            break;
          }
          peer = _bytes(address);
        }
      }
    }
    if (_trusted(peer)) peer = _bytes(transport);
    return '${peer.length}:${peer.join(',')}';
  }

  bool _trusted(List<int> address) =>
      _networks.any((network) => network.contains(address));
}

List<int> _bytes(InternetAddress address) {
  final bytes = address.rawAddress;
  // IPv4 and its IPv6-mapped spelling are the same peer.
  if (bytes.length == 16 &&
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 255 &&
      bytes[11] == 255) {
    return bytes.sublist(12);
  }
  return bytes;
}

final class _ProxyNetwork {
  const _ProxyNetwork(this.bytes, this.prefix);

  factory _ProxyNetwork.parse(String text) {
    final parts = text.split('/');
    if (parts.length != 2) throw const FormatException('CIDR required');
    final address = InternetAddress.tryParse(parts.first);
    var prefix = int.tryParse(parts.last);
    if (address == null ||
        prefix == null ||
        prefix < 1 ||
        prefix > address.rawAddress.length * 8) {
      throw const FormatException('invalid network prefix');
    }
    final bytes = _bytes(address);
    if (address.rawAddress.length != bytes.length) {
      prefix -= 96;
      if (prefix < 1) throw const FormatException('invalid mapped prefix');
    }
    return _ProxyNetwork(bytes, prefix);
  }

  final List<int> bytes;
  final int prefix;

  bool contains(List<int> address) {
    if (address.length != bytes.length) return false;
    for (var offset = 0; offset < prefix; offset += 8) {
      final bits = (prefix - offset).clamp(1, 8);
      final mask = (255 << (8 - bits)) & 255;
      final index = offset ~/ 8;
      if ((address[index] & mask) != (bytes[index] & mask)) return false;
    }
    return true;
  }
}

final class _PeerQuota {
  _PeerQuota(this.limit);

  final DwCallRateLimit limit;
  final Map<String, _PeerDebt> _peers = {};
  int? _lastSweep;

  int get _capacity => limit.period.inMicroseconds * (limit.burst + 1);
  int get _idleMicros => _ceilDivide(_capacity, limit.requests);

  Duration? charge(String peer, DateTime now) {
    final instant = now.microsecondsSinceEpoch;
    var bucket = _peers[peer];
    if (bucket == null) {
      if (_peers.length >= limit.maxPeers) {
        // A rotating source cannot force a full table scan on every request.
        final sweepEvery = _idleMicros.clamp(1, Duration.microsecondsPerSecond);
        if (_lastSweep == null || instant - _lastSweep! >= sweepEvery) {
          _peers.removeWhere((_, debt) => instant - debt.at >= _idleMicros);
          _lastSweep = instant;
        }
        if (_peers.length >= limit.maxPeers) return _retry(_idleMicros);
      }
      bucket = _PeerDebt(instant, 0);
      _peers[peer] = bucket;
    }
    final elapsed = (instant - bucket.at).clamp(0, _idleMicros);
    final remaining = elapsed >= _idleMicros
        ? 0
        : bucket.debt - elapsed * limit.requests;
    bucket.debt = remaining < 0 ? 0 : remaining;
    if (instant > bucket.at) bucket.at = instant;
    final threshold = _capacity - limit.period.inMicroseconds;
    if (bucket.debt > threshold) {
      return _retry(_ceilDivide(bucket.debt - threshold, limit.requests));
    }
    bucket.debt += limit.period.inMicroseconds;
    return null;
  }

  static int _ceilDivide(int numerator, int denominator) =>
      numerator ~/ denominator + (numerator % denominator == 0 ? 0 : 1);

  static Duration _retry(int micros) =>
      Duration(seconds: _ceilDivide(micros, Duration.microsecondsPerSecond));
}

final class _PeerDebt {
  _PeerDebt(this.at, this.debt);

  int at;
  int debt;
}
