import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// A package left out of the plan because pub.dev already lists its version —
/// exactly how `dartway_shared_preferences`, `dartway_telegram` and
/// `dartway_studio_bridge` fell a release behind their own code before this
/// check existed: each moved onto the rewrite without its version following,
/// and nothing asked pub.dev's own timestamp whether that was still true.
void main() {
  DateTime? never(String name, String version) => null;
  List<String> nothingChanged(String directory, DateTime since) => const [];

  test('a package untouched since its own publish is not stale', () {
    final stale = staleVersionsAmong(
      [
        (
          name: 'dartway_router',
          version: '2.0.0',
          directory: 'packages/dartway_router',
        ),
      ],
      publishedAt: (name, version) => DateTime.utc(2026, 1, 1),
      changedPathsSince: nothingChanged,
    );
    expect(stale, isEmpty);
  });

  test('a package whose lib/ moved after its publish date is stale', () {
    final stale = staleVersionsAmong(
      [
        (
          name: 'dartway_shared_preferences',
          version: '0.5.0',
          directory: 'packages/dartway_shared_preferences',
        ),
      ],
      publishedAt: (name, version) => DateTime.utc(2026, 1, 1),
      changedPathsSince: (directory, since) => [
        '$directory/lib/src/dw_shared_preferences.dart',
      ],
    );
    expect(stale, hasLength(1));
    expect(stale.single.package, 'dartway_shared_preferences');
    expect(stale.single.version, '0.5.0');
    expect(
      stale.single.toString(),
      contains('changed since'),
      reason:
          'the report names what changed and why it matters, not just a '
          'package name',
    );
  });

  test('a package pub.dev has never published is not this check\'s to raise '
      '— unresolvableDependenciesOf already covers a package with nothing '
      'published at all', () {
    final stale = staleVersionsAmong(
      [
        (
          name: 'dartway_auth_apple',
          version: '0.1.0',
          directory: 'packages/dartway_auth_apple',
        ),
      ],
      publishedAt: never,
      changedPathsSince: (directory, since) =>
          throw StateError('must not be asked when never published'),
    );
    expect(stale, isEmpty);
  });

  test(
    'comparing against the publish timestamp rather than a stable tag avoids '
    'the false positive of a package published from a commit `stable` has '
    'not reached yet — the caller is expected to pass the pub.dev publish '
    'instant here, not a tag date, and this only proves the function does '
    'not add its own drift on top',
    () {
      final publishedAt = DateTime.utc(2026, 9, 20, 12);
      final stale = staleVersionsAmong(
        [
          (
            name: 'dartway_cli',
            version: '0.11.1',
            directory: 'packages/dartway_cli',
          ),
        ],
        publishedAt: (name, version) => publishedAt,
        changedPathsSince: (directory, since) {
          expect(since, publishedAt);
          return const [];
        },
      );
      expect(stale, isEmpty);
    },
  );
}
