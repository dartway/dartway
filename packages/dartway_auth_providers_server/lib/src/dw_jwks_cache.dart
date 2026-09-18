import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'dw_jwt_keys.dart';

/// A provider's key set as it was fetched: the document, and how long it may
/// be held before asking again.
typedef DwJwksDocument = ({Object? document, Duration? maxAge});

/// Fetches a key set. Replaced in tests, and by a project that wants its own
/// HTTP client.
typedef DwJwksFetch = Future<DwJwksDocument> Function(Uri uri);

/// The provider could not be asked for its signing keys, and none are held.
final class DwJwksUnavailable implements Exception {
  const DwJwksUnavailable(this.uri, this.cause);

  final Uri uri;
  final Object cause;

  @override
  String toString() => 'Cannot read the key set at $uri: $cause';
}

/// A provider's published signing keys, kept between sign-ins.
///
/// Both providers rotate their keys, so nothing is pinned: the set is fetched
/// on the first sign-in and held for as long as the provider's `Cache-Control`
/// says ([fallbackLifetime] when it says nothing, [maximumLifetime] at the
/// most). A token naming a key id the held set does not have is what a
/// rotation looks like, so the set is fetched again — at most once every
/// [minimumRefreshGap], which is what keeps a stream of tokens with a made-up
/// key id from becoming a stream of requests to the provider.
///
/// A fetch that fails while a set is held keeps the held one: keys outlive
/// their cache entry by far, and a provider that is briefly unreachable must
/// not close the door on everyone signing in.
final class DwJwksCache {
  DwJwksCache(
    this.uri, {
    DwJwksFetch? fetch,
    this.minimumRefreshGap = const Duration(minutes: 1),
    this.fallbackLifetime = const Duration(hours: 1),
    this.maximumLifetime = const Duration(hours: 24),
    @visibleForTesting DateTime Function()? now,
  }) : _fetch = fetch ?? _fetchOverHttp,
       _now = now ?? DateTime.now;

  final Uri uri;
  final DwJwksFetch _fetch;
  final DateTime Function() _now;
  final Duration minimumRefreshGap;
  final Duration fallbackLifetime;
  final Duration maximumLifetime;

  List<DwJwtKey> _keys = const [];
  DateTime? _freshUntil;
  DateTime? _lastFetch;
  Future<void>? _fetching;

  /// The keys that can verify a token whose header names [kid], fetching the
  /// set when none is held, when it is stale, or when [kid] is unknown and
  /// the provider may be asked again.
  ///
  /// Empty when the provider publishes no key of that id; throws
  /// [DwJwksUnavailable] when nothing is held and the provider cannot be
  /// reached.
  Future<List<DwJwtKey>> keysFor(String kid) async {
    final held = _matching(kid);
    if (held.isNotEmpty && !_stale) return held;
    if (_keys.isEmpty || _stale || _mayRefresh) await _refresh();
    return _matching(kid);
  }

  /// Everything held, without asking the provider — what a diagnostic reads.
  @visibleForTesting
  List<DwJwtKey> get held => List.unmodifiable(_keys);

  bool get _stale {
    final until = _freshUntil;
    return until == null || !_now().isBefore(until);
  }

  bool get _mayRefresh {
    final last = _lastFetch;
    return last == null || _now().difference(last) >= minimumRefreshGap;
  }

  List<DwJwtKey> _matching(String kid) => [
    for (final key in _keys)
      if (kid.isEmpty || key.kid.isEmpty || key.kid == kid) key,
  ];

  /// One fetch at a time: a burst of sign-ins after a rotation asks the
  /// provider once, not once per caller.
  Future<void> _refresh() {
    return _fetching ??= () async {
      try {
        _lastFetch = _now();
        final answer = await _fetch(uri);
        final keys = DwJwtKey.parseSet(answer.document);
        // A set that parses to nothing is not an answer: keep what is held
        // and let the caller refuse this token rather than every token.
        if (keys.isEmpty) {
          if (_keys.isEmpty) {
            throw const FormatException(
              'the key set holds no key this server can verify with',
            );
          }
        } else {
          _keys = keys;
        }
        final maxAge = answer.maxAge ?? fallbackLifetime;
        _freshUntil = _now().add(
          maxAge > maximumLifetime ? maximumLifetime : maxAge,
        );
      } on Object catch (error) {
        if (_keys.isEmpty) throw DwJwksUnavailable(uri, error);
        // Held keys stay usable; the next sign-in tries the provider again
        // once the gap has passed.
        _freshUntil = _now().add(minimumRefreshGap);
      } finally {
        _fetching = null;
      }
    }();
  }

  static Future<DwJwksDocument> _fetchOverHttp(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'the key set answered ${response.statusCode}',
          uri: uri,
        );
      }
      return (document: jsonDecode(body), maxAge: _maxAgeOf(response.headers));
    } finally {
      client.close(force: true);
    }
  }

  /// `max-age` of the answer's `Cache-Control`, which is how long the
  /// provider says the set may be held.
  static Duration? _maxAgeOf(HttpHeaders headers) {
    final control = headers.value(HttpHeaders.cacheControlHeader);
    if (control == null) return null;
    final match = RegExp(r'max-age\s*=\s*(\d+)').firstMatch(control);
    final seconds = match == null ? null : int.tryParse(match.group(1)!);
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}
