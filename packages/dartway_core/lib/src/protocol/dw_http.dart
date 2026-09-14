/// The version of the framework envelope: call paths and headers, the
/// `DwApiResponse` body, the transport, the live messages. A client sends it
/// on every call (`Dw-Protocol`) and on the live upgrade (`?protocol=`); a
/// server that does not speak it answers `426` with `dw.protocolUnsupported`.
const int dwProtocolVersion = 1;

/// The HTTP contract between a DartWay client and its server, declared once
/// for both sides:
///
/// ```
/// POST /dw/<DtoWireName>   a request or a command; the body is the DTO's JSON
/// GET  /dw/live            the WebSocket of live updates
/// GET  /health             liveness and database reachability
/// ```
///
/// `/dw/` and `/health` are reserved: a project route under them fails the
/// server's startup.
abstract final class DwHttp {
  /// The prefix of every framework path.
  static const String pathPrefix = '/dw/';

  /// The segment of the live path; never a DTO name (`DwProtocol` refuses it).
  static const String liveSegment = 'live';

  /// The WebSocket of live updates.
  static const String livePath = '$pathPrefix$liveSegment';

  static const String healthPath = '/health';

  /// Calls are POST only: a request is a read, but its parameters are a DTO
  /// body, and one method keeps one code path.
  static const String callMethod = 'POST';

  /// The path of a call to the DTO registered as [wireName].
  static String callPath(String wireName) => '$pathPrefix$wireName';

  /// The wire name a call [path] names, or `null` when [path] is not a call
  /// path (outside the prefix, empty, nested, or the live path).
  static String? wireNameOf(String path) {
    if (!path.startsWith(pathPrefix)) return null;
    final name = path.substring(pathPrefix.length);
    if (name.isEmpty || name.contains('/') || name == liveSegment) return null;
    return name;
  }

  // Headers. HTTP header names are case-insensitive; these are the spellings
  // the framework writes.

  /// `Bearer <token>`; absent for an anonymous call.
  static const String authorizationHeader = 'Authorization';

  /// The prefix of the [authorizationHeader] value.
  static const String bearerPrefix = 'Bearer ';

  /// Required for commands, forbidden for requests.
  static const String idempotencyKeyHeader = 'Dw-Idempotency-Key';

  /// [dwProtocolVersion]; required on every call.
  static const String protocolHeader = 'Dw-Protocol';

  /// The app build, `<semver>+<build>` (see `DwAppVersion`); a build below the
  /// server's minimum answers `426` with `dw.updateRequired`.
  static const String appVersionHeader = 'Dw-App-Version';

  /// The id the server gave this client's live connection (the `hello`
  /// message). Optional: it excludes that connection from the socket
  /// broadcast of the call's updates and filters the response's transport to
  /// the connection's subscriptions.
  static const String liveConnectionHeader = 'Dw-Live-Connection';

  /// Whole seconds, on a `429` answer.
  static const String retryAfterHeader = 'Retry-After';

  static const String contentTypeHeader = 'Content-Type';

  /// The content type of every call body and every answer.
  static const String jsonContentType = 'application/json; charset=utf-8';

  // Query parameters.

  /// Page request: the number of rows already loaded.
  static const String offsetParameter = 'offset';

  /// Page and window requests: rows asked for, clamped by the request's
  /// `maxPageSize`. A table request's page size is a field of the request.
  static const String pageSizeParameter = 'pageSize';

  /// Window request: open around the row of this cursor.
  static const String anchorParameter = 'anchor';

  /// Window request: rows older than this cursor.
  static const String beforeParameter = 'before';

  /// Window request: rows newer than this cursor.
  static const String afterParameter = 'after';

  /// Live upgrade: [dwProtocolVersion] (browsers cannot set upgrade headers).
  static const String liveProtocolParameter = 'protocol';

  /// Live upgrade: the app version, as in [appVersionHeader].
  static const String liveAppVersionParameter = 'app';
}

/// An app build as the client reports it: `1.4.2+87`.
///
/// The server compares [build] with its `minAppBuild`; the name is for
/// people. One parser for both sides, so a version the client can send is a
/// version the server can read.
final class DwAppVersion {
  /// Throws [ArgumentError] for a negative build or a name that is not a
  /// semantic version.
  DwAppVersion(this.name, this.build) {
    if (build < 0) throw ArgumentError.value(build, 'build', 'is negative');
    if (!_semver.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'is not a semantic version');
    }
  }

  /// Reads `<semver>+<build>`. Throws [FormatException] for anything else.
  static DwAppVersion parse(String text) {
    final plus = text.lastIndexOf('+');
    if (plus < 0) {
      throw FormatException('An app version is <semver>+<build>', text);
    }
    final buildText = text.substring(plus + 1);
    final build = int.tryParse(buildText);
    if (build == null || '$build' != buildText) {
      throw FormatException('The build of an app version is a number', text);
    }
    try {
      return DwAppVersion(text.substring(0, plus), build);
    } on ArgumentError catch (error) {
      throw FormatException('${error.message}', text);
    }
  }

  static final _semver = RegExp(
    r'^\d+\.\d+\.\d+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$',
  );

  final String name;
  final int build;

  @override
  bool operator ==(Object other) =>
      other is DwAppVersion && other.name == name && other.build == build;

  @override
  int get hashCode => Object.hash(name, build);

  /// The header value.
  @override
  String toString() => '$name+$build';
}
