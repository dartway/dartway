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
