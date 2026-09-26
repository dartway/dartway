import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Recognising pub.dev's `package-created` rate limit answer (#313) from
/// what `dart pub publish` prints — the exact text quoted in the issue for
/// the short window, and a plausible daily-window shape for the long one,
/// since pub.dev only ever showed this run the short one.
void main() {
  test('the exact short-window message from #313 parses', () {
    final limit = PackageCreatedRateLimit.parse(
      'The "package-created" operation is blocked, as its rate limit has '
      'been reached (4 in the last few minutes).',
    );
    expect(limit, isNotNull);
    expect(limit!.count, 4);
    expect(limit.window, 'few minutes');
    expect(limit.isShortWindow, isTrue);
  });

  test("pub.dev's real daily-window text parses and is not the short window "
      '(review of PR #358, N6)', () {
    final limit = PackageCreatedRateLimit.parse(
      'The "package-created" operation is blocked, as its rate limit has '
      'been reached (12 in the last day).',
    );
    expect(limit, isNotNull);
    expect(limit!.count, 12);
    expect(limit.window, 'day');
    expect(limit.isShortWindow, isFalse);
  });

  test('the message can sit among other pub output, not alone', () {
    final limit = PackageCreatedRateLimit.parse(
      'Publishing dartway_auth_google 0.1.0 to https://pub.dev\n'
      'Uploading...\n'
      'The "package-created" operation is blocked, as its rate limit has '
      'been reached (4 in the last few minutes).\n'
      'FAILED\n',
    );
    expect(limit, isNotNull);
    expect(limit!.count, 4);
  });

  test('an ordinary failure is not read as a rate limit', () {
    expect(
      PackageCreatedRateLimit.parse(
        'FormatException: The lower bound of "sdk: \'>=2.12.0\'" must be '
        'greater than 0.0.0\n',
      ),
      isNull,
    );
  });

  test("a different pub.dev rate limit — package-published, not "
      'package-created — is not matched: this feature is about first '
      'publications only (review of PR #358, N6)', () {
    expect(
      PackageCreatedRateLimit.parse(
        'The "package-published" operation is blocked, as its rate limit '
        'has been reached (24 in the last day).',
      ),
      isNull,
    );
  });

  test('toString reads count and window together', () {
    const limit = PackageCreatedRateLimit(count: 4, window: 'a few minutes');
    expect(limit.toString(), '4 in the last a few minutes');
  });
}
