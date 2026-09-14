import 'package:meta/meta.dart';

/// A browser origin as the `Origin` header carries it: scheme, host and port.
///
/// Two pages are the same origin only when all three agree, so the live
/// socket's origin check compares all three: `http://localhost:5000` is not
/// `http://localhost:8080`, and `http://app.example.com` is not
/// `https://app.example.com`.
@internal
final class DwWebOrigin {
  const DwWebOrigin._(this.scheme, this.host, this.port);

  /// Parses a serialised origin — `https://app.example.com`,
  /// `http://localhost:5000` — or returns `null` for anything else: another
  /// scheme than `http`/`https`, no host, a path, a query, a fragment or user
  /// info. Scheme and host are compared case-insensitively; a port left out is
  /// the scheme's default.
  static DwWebOrigin? parse(String text) {
    final Uri uri;
    try {
      uri = Uri.parse(text.trim());
    } on FormatException {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') ||
        uri.host.isEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return DwWebOrigin._(scheme, uri.host.toLowerCase(), uri.port);
  }

  final String scheme;
  final String host;
  final int port;

  /// Whether this origin is the host a request was sent to, as its `Host`
  /// header names it (`app.example.com`, `localhost:8080`, `[::1]:8080`).
  ///
  /// `Host` carries no scheme — behind a TLS-terminating proxy the server
  /// cannot know it either — so host and port are compared, a port left out of
  /// `Host` being this origin's scheme default. A deployment serving one host
  /// over both schemes redirects `http` to `https` at its proxy.
  bool isHostOf(String? hostHeader) {
    if (hostHeader == null || hostHeader.isEmpty) return false;
    final Uri uri;
    try {
      uri = Uri.parse('//$hostHeader');
    } on FormatException {
      return false;
    }
    if (uri.host.isEmpty || uri.path.isNotEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    final hostPort = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    return uri.host.toLowerCase() == host && hostPort == port;
  }

  @override
  bool operator ==(Object other) =>
      other is DwWebOrigin &&
      other.scheme == scheme &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(scheme, host, port);

  @override
  String toString() => '$scheme://$host:$port';
}
