import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Two packages that cannot depend on each other still have to agree on one
/// character, and a comment saying so is a rule with nothing to break.
///
/// A declared path says "a value goes here" with a leading `:` — go_router's
/// spelling. The router matches a live route against it; the Studio bridge
/// matches an address against the manifest and publishes the predicate for
/// Studio to read. The router cannot depend on the bridge (the bridge is the
/// wire, the router is the UI, and inverting that for a predicate is worse
/// than the disease), so nothing in either package fails when one of them
/// starts meaning something else.
///
/// This does: it reads both files and compares what they actually say. It
/// lives here because this package is the one that sees the whole monorepo.
void main() {
  final packages = Directory(p.join(Directory.current.parent.path));

  String sourceOf(String relative) {
    final file = File(p.join(packages.path, relative));
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$relative moved; the two spellings it kept in step are now '
          'unwatched — point this test at the new place',
    );
    return file.readAsStringSync();
  }

  /// The placeholder prefix as [source] spells it, from the one line that
  /// decides it.
  String spellingIn(String source, RegExp around) {
    final match = around.firstMatch(source);
    expect(
      match,
      isNotNull,
      reason: 'the line deciding the template spelling is not where it was',
    );
    return match!.group(1)!;
  }

  test('the router and the bridge call a template segment the same thing', () {
    final router = spellingIn(
      sourceOf(
        p.join(
          'dartway_router',
          'lib',
          'src',
          'navigation_zones',
          'dw_navigation_route_extension.dart',
        ),
      ),
      RegExp(r"final expected = segment\.startsWith\('(.+?)'\)"),
    );
    final bridge = spellingIn(
      sourceOf(
        p.join(
          'dartway_studio_bridge',
          'lib',
          'src',
          'models',
          'studio_manifest_index.dart',
        ),
      ),
      RegExp(r"static bool isPlaceholder\(String segment\) =>\s*"
          r"segment\.startsWith\('(.+?)'\)"),
    );
    expect(
      router,
      bridge,
      reason:
          'a route declared in the app and the same route in the manifest '
          'would stop matching, and each package would keep passing its own '
          'tests',
    );
  });
}
