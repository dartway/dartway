import 'package:dartway_auth_providers_server/dartway_auth_providers_server.dart';

/// A provider's key set as a test serves it: what it answers, how often it
/// was asked, and whether it can be reached at all.
final class FakeKeySet {
  FakeKeySet(this.answer, {this.maxAge});

  /// The document the next fetch returns.
  Map<String, Object?> answer;

  /// What the provider's `Cache-Control` says, if anything.
  Duration? maxAge;

  /// When set, a fetch fails with this message instead of answering.
  String? failWith;

  /// How many times the provider was asked.
  int fetches = 0;

  Future<DwJwksDocument> fetch(Uri uri) async {
    fetches++;
    final failure = failWith;
    if (failure != null) throw StateError(failure);
    return (document: answer, maxAge: maxAge);
  }
}

/// Apple's `/auth/token` and `/auth/revoke` as a test serves them: what was
/// asked, and what to answer.
final class FakeApple {
  /// Every form posted, by the path it went to.
  final List<({String path, Map<String, String> form})> calls = [];

  /// The refresh token `/auth/token` hands out; null answers without one.
  String? refreshToken = 'apple-refresh-token';

  /// When set, the next call answers this status with `{'error': …}`.
  int? failWith;

  Future<DwAppleAnswer> post(Uri uri, Map<String, String> form) async {
    calls.add((path: uri.path, form: form));
    final failure = failWith;
    if (failure != null) {
      return (status: failure, body: <String, Object?>{'error': 'invalid_grant'});
    }
    if (uri.path.endsWith('/token')) {
      return (
        status: 200,
        body: <String, Object?>{'refresh_token': ?refreshToken},
      );
    }
    return (status: 200, body: <String, Object?>{});
  }

  /// The forms posted to one endpoint.
  List<Map<String, String>> to(String path) => [
    for (final call in calls)
      if (call.path.endsWith(path)) call.form,
  ];
}
