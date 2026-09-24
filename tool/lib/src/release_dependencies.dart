/// Whether a package's own `dartway_*` dependencies can resolve once a
/// release plan goes out — from the plan itself, or from what pub.dev
/// already holds.
///
/// `ReleaseOrder` only ever asked whether a package in the plan comes after
/// whatever else *in the plan* it depends on. It never asked whether a
/// dependency *outside* the plan actually resolves anywhere — which let a
/// plan propose publishing `dartway_core_flutter`, stating carets on
/// `dartway_client` and `dartway_core_shared`, while both were still
/// `publish_to: none` and in nobody's plan at all. Nothing here would have
/// refused that plan; pub.dev would have, the moment `dartway_core_flutter`
/// went out and a stranger tried to resolve it.
library;

import 'plain_version.dart';

/// A local package's shape, as far as publishing needs to know: whether it
/// can ever be published at all, and the `dartway_*` carets on its
/// `dependencies:` section — never `dependency_overrides`, which resolves
/// only inside this workspace and never travels to pub.dev.
class LocalPackageShape {
  const LocalPackageShape({required this.name, required this.publishToNone});

  final String name;
  final bool publishToNone;
}

/// One package of a release plan, in the order it would publish — just
/// enough of `_Package` (`release.dart`) for this check to read.
abstract interface class PlannedRelease {
  String get name;

  /// `dartway_*` dependency name → the caret text stated for it (`^0.20.0`).
  /// A constraint this script cannot parse as a caret is still checked, by
  /// exact text match against what is published — `dart pub publish` would
  /// refuse an unparseable one long before this script runs.
  Map<String, String> get dependencyConstraints;
}

/// Why a dependency of a planned package would not resolve, in the words a
/// person reads before anything is published.
class UnresolvableDependency {
  const UnresolvableDependency(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every dependency in [plan] that would not resolve once the plan is
/// carried out: neither earlier in the plan, nor already on pub.dev at a
/// version its caret allows.
///
/// Reported rather than thrown — the caller decides how many to print before
/// refusing to publish anything, per the header's exit-code contract in
/// `release.dart`.
List<UnresolvableDependency> unresolvableDependenciesOf(
  List<PlannedRelease> plan, {
  required Map<String, LocalPackageShape> localPackages,
  required Map<String, Set<String>> pubDevVersions,
}) {
  final positionInPlan = {
    for (var i = 0; i < plan.length; i++) plan[i].name: i,
  };
  final problems = <UnresolvableDependency>[];

  for (var i = 0; i < plan.length; i++) {
    final package = plan[i];
    for (final MapEntry(key: depName, value: constraint)
        in package.dependencyConstraints.entries) {
      final atInPlan = positionInPlan[depName];
      if (atInPlan != null) {
        // Ordinarily caught by `ReleaseOrder.verify` first, on the same plan
        // — this is the same fact stated in this check's own words, so a
        // reader of just this report is not sent to guess at the other one.
        if (atInPlan >= i) {
          problems.add(
            UnresolvableDependency(
              '${package.name} depends on $depName ($constraint), which this '
              'plan publishes at position ${atInPlan + 1} — not before '
              '${package.name} at position ${i + 1}.',
            ),
          );
        }
        continue;
      }

      final local = localPackages[depName];
      if (local != null && local.publishToNone) {
        problems.add(
          UnresolvableDependency(
            '${package.name} depends on $depName ($constraint), which is '
            '`publish_to: none` and is not in this plan either — a stranger '
            'resolving ${package.name} from pub.dev can never satisfy that.',
          ),
        );
        continue;
      }

      final onPubDev = pubDevVersions[depName] ?? const <String>{};
      if (!_satisfies(constraint, onPubDev)) {
        problems.add(
          UnresolvableDependency(
            '${package.name} depends on $depName ($constraint), which is not '
            'in this plan, and pub.dev has no version satisfying it '
            '(published: ${onPubDev.isEmpty ? 'nothing' : (onPubDev.toList()..sort()).join(', ')}).',
          ),
        );
      }
    }
  }
  return problems;
}

bool _satisfies(String constraint, Set<String> published) {
  final base = _caretBase(constraint);
  if (base == null) {
    // Not a caret this script parses (an exact version, "any", a git or path
    // constraint under `dependencies:` — unusual, but not this script's call
    // to refuse): fall back to an exact match against what is out.
    return published.contains(constraint);
  }
  return published.any((version) {
    final parsed = PlainVersion.tryParse(version);
    return parsed != null && base.allows(parsed);
  });
}

PlainVersion? _caretBase(String constraint) {
  final text = constraint.trim();
  if (!text.startsWith('^')) return null;
  return PlainVersion.tryParse(text.substring(1));
}
