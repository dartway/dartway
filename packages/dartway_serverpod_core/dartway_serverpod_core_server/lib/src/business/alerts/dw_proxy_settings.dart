/// One outbound proxy, parsed out of a `passwords.yaml` value.
///
/// Internal to the package: apps never build one, they set the key and get a
/// client back from `DwProxyHttpClient.fromEnv`. It is a type of its own so
/// that the parsing — the part that quietly goes wrong in production, on a
/// machine nobody can attach a debugger to — is testable without opening a
/// socket.
class DwProxySettings {
  final String host;
  final int port;

  /// Proxy credentials, both null when the URL carried none.
  final String? username;
  final String? password;

  const DwProxySettings({
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  bool get hasCredentials => username != null && password != null;

  /// The proxy configuration string `HttpClient.findProxy` answers with.
  String get proxyConfiguration => 'PROXY $host:$port';

  /// Parses `http://user:pass@host:port` (credentials and port optional).
  ///
  /// Returns null for anything else — a missing value, a blank one, a bare
  /// `host:port` with no scheme, junk — rather than guessing. A proxy is used
  /// where the direct route is blocked, so a half-understood value would not
  /// degrade to something slower, it would degrade to alerts that never arrive
  /// while the config says they should. [logFunction] is how that becomes
  /// audible; the library never writes to stdout on its own.
  static DwProxySettings? parse(
    String? raw, {
    void Function(String message)? logFunction,
  }) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    void reject(String reason) => logFunction?.call(
      'DwProxySettings.parse: $reason — expected '
      'http://user:pass@host:port (credentials optional). Proxy stays off.',
    );

    final uri = Uri.tryParse(value);
    if (uri == null) {
      reject('not a URL');
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      reject(
        uri.scheme.isEmpty
            ? 'no scheme'
            : 'unsupported scheme "${uri.scheme}"',
      );
      return null;
    }

    if (uri.host.isEmpty) {
      reject('no host');
      return null;
    }

    // `uri.port` falls back to the scheme default (80/443) when the URL states
    // none, so a proxy written without a port still resolves to something.
    final port = uri.port;
    if (port <= 0 || port > 65535) {
      reject('port $port is out of range');
      return null;
    }

    if (uri.userInfo.isEmpty) {
      return DwProxySettings(host: uri.host, port: port);
    }

    final separator = uri.userInfo.indexOf(':');
    final rawUsername = separator == -1
        ? uri.userInfo
        : uri.userInfo.substring(0, separator);
    final rawPassword = separator == -1
        ? ''
        : uri.userInfo.substring(separator + 1);

    final String username;
    final String password;
    try {
      // `Uri.userInfo` hands back the escapes as written — a password with a
      // `@`, a `:` or a `/` in it has to arrive percent-encoded, and would
      // otherwise be sent to the proxy literally as `%40`.
      username = Uri.decodeComponent(rawUsername);
      password = Uri.decodeComponent(rawPassword);
    } on FormatException {
      // `Uri.parse` repairs a lone `%` on its own (it becomes `%25`), so what
      // reaches here is a well-formed escape of something that is not UTF-8.
      reject('credentials are not valid percent-encoded UTF-8');
      return null;
    }

    if (username.isEmpty) {
      reject('credentials with an empty user name');
      return null;
    }

    return DwProxySettings(
      host: uri.host,
      port: port,
      username: username,
      password: password,
    );
  }

  @override
  String toString() =>
      'DwProxySettings($host:$port, '
      '${hasCredentials ? 'authenticated' : 'anonymous'})';
}
