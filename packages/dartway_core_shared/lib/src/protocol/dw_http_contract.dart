/// The version of the framework envelope: call paths and headers, the
/// `DwApiResponse` body, the transport, the live messages. A client sends it
/// on every call (`Dw-Protocol`) and on the live upgrade (`?protocol=`); a
/// server that does not speak it answers `426` with `dw.protocolUnsupported`.
const int dwProtocolVersion = 2;

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
abstract final class DwHttpContract {
  /// The prefix of every framework path.
  static const String pathPrefix = '/dw/';

  /// The segment of the live path; never a DTO name (`DwWireProtocol` refuses
  /// it).
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

  /// The app build, `<semver>+<build>` (see `DwAppVersion`). For people: the
  /// label of the session key the app signs in with. Compatibility is the
  /// contract's, in [contractVersionHeader].
  static const String appVersionHeader = 'Dw-App-Version';

  /// The version of the project's contract the app was compiled with (see
  /// `DwContractVersion`): a client of an older breaking line than the
  /// server's is answered `426` with `dw.updateRequired`.
  static const String contractVersionHeader = 'Dw-Contract-Version';

  /// The id the server gave this client's live connection (the `hello`
  /// message). Optional: it excludes that connection from the socket
  /// broadcast of the call's updates, whose channels the response carries
  /// instead. With it or without, the response carries the channels the
  /// caller may read (D-053); a connection that is not the caller's is
  /// ignored.
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

  /// Live upgrade: the contract version, as in [contractVersionHeader].
  static const String liveContractVersionParameter = 'contract';
}

/// An app build as the client reports it: `1.4.2+87`.
///
/// For people — it labels the session key the app signs in with. Whether an
/// app may call is the contract's question (`DwContractVersion`). One parser
/// for both sides, so a version the client can send is a version the server
/// can read.
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

/// The version of a project's contract — its shared package's `version:`,
/// which the generator writes into the protocol both sides are compiled with.
///
/// Semantic versioning decides compatibility, and nothing else does: a change
/// that breaks an installed app — a request, command, field or value removed
/// or renamed — raises the **breaking line** (the major version, or the minor
/// one below 1.0); anything additive does not. A server answers a client of
/// an older line than its own `426` with `dw.updateRequired`, and the app
/// shows its update screen. The minimum lives in the code, raised in the pull
/// request that breaks the contract, rather than in an environment someone
/// has to remember at deploy (#296).
///
/// A client of a newer line than the server is not refused: the server is the
/// one behind, and a call it does not know is answered as unknown.
final class DwContractVersion {
  /// Throws [ArgumentError] for a text that is not a semantic version.
  DwContractVersion(this.text) {
    final match = _semver.firstMatch(text);
    if (match == null) {
      throw ArgumentError.value(text, 'text', 'is not a semantic version');
    }
    final major = int.parse(match[1]!);
    line = major > 0 ? '$major' : '0.${int.parse(match[2]!)}';
    _major = major;
    _minor = int.parse(match[2]!);
  }

  /// Reads a header value; [FormatException] for anything but a semantic
  /// version.
  static DwContractVersion parse(String text) {
    try {
      return DwContractVersion(text);
    } on ArgumentError catch (error) {
      throw FormatException('${error.message}', text);
    }
  }

  static final _semver = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$',
  );

  final String text;

  /// The breaking line: `3` for `3.4.1`, `0.7` for `0.7.2`.
  late final String line;

  late final int _major;
  late final int _minor;

  /// Whether this version belongs to an older breaking line than [other]:
  /// an app on it cannot speak [other]'s contract.
  bool isOlderLineThan(DwContractVersion other) {
    if (_major != other._major) return _major < other._major;
    if (_major > 0) return false;
    return _minor < other._minor;
  }

  @override
  bool operator ==(Object other) =>
      other is DwContractVersion && other.text == text;

  @override
  int get hashCode => text.hashCode;

  /// The header value.
  @override
  String toString() => text;
}
