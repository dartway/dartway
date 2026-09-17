/// A package of a release: its name and the packages it depends on.
abstract interface class ReleaseUnit {
  String get name;
  Set<String> get dependencies;
}

/// The order a release publishes in, and the check of that order.
class ReleaseOrder {
  const ReleaseOrder._();

  /// The plan, ordered so that nothing is published before what it depends on.
  ///
  /// Only packages inside the plan constrain each other: a dependency that is
  /// already published at the version stated is on pub.dev before this run starts.
  static List<T> of<T extends ReleaseUnit>(List<T> plan) {
    final byName = {for (final p in plan) p.name: p};
    final ordered = <T>[];
    final placed = <String>{};

    // A dependency cycle cannot exist in a resolvable workspace, but a bug here
    // must not become an infinite loop in a script that publishes.
    while (ordered.length < plan.length) {
      final ready = plan
          .where((p) => !placed.contains(p.name))
          .where(
            (p) => p.dependencies.every(
              (d) => !byName.containsKey(d) || placed.contains(d),
            ),
          )
          .toList();

      if (ready.isEmpty) {
        final stuck = plan
            .where((p) => !placed.contains(p.name))
            .map((p) => p.name);
        throw StateError(
          'Cannot order the release: ${stuck.join(', ')} depend on each other. '
          'A cycle among dartway packages is not resolvable on pub.dev either.',
        );
      }

      for (final p in ready) {
        ordered.add(p);
        placed.add(p.name);
      }
    }
    return ordered;
  }

  /// Checks the answer the ordering just gave, before anything acts on it.
  ///
  /// The order is the whole value of this script and the one thing a mistake in
  /// it cannot be taken back from: publishing a dependent before its dependency
  /// fails on version solving with part of the release already out, permanently.
  /// So the result is verified rather than trusted — the check is four lines and
  /// reads nothing the sort read.
  static void verify(List<ReleaseUnit> plan) {
    final position = {for (var i = 0; i < plan.length; i++) plan[i].name: i};
    for (var i = 0; i < plan.length; i++) {
      for (final dependency in plan[i].dependencies) {
        final at = position[dependency];
        if (at != null && at > i) {
          throw StateError(
            'Ordering is wrong: ${plan[i].name} would be published at ${i + 1}, '
            'before ${plan[at].name} at ${at + 1}, which it depends on. '
            'Refusing to act on it.',
          );
        }
      }
    }
  }
}
