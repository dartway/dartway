/// Guard checks for an application's router-state records.
library;

import 'src/navigation_zones/dw_navigation_route.dart';
import 'src/navigation_zones/dw_navigation_route_extension.dart';
import 'src/navigation_zones/dw_navigation_types.dart';

/// Runs every route's guards with each nullable field independently unknown.
///
/// Dart records cannot enumerate or replace fields at runtime. Supply a setter
/// for each nullable field and representative known states (including values
/// that redirect). A guard that allows an unknown value where the corresponding
/// known value redirects throws [StateError], naming the zone, route and field.
/// Parameterized or query-sensitive routes can supply concrete [targets].
void dwCheckPendingGuards<S>({
  required List<List<DwNavigationRoute<S>>> navigationZones,
  required Iterable<S> knownStates,
  required Map<String, S Function(S)> nullableFields,
  Map<DwNavigationRoute<S>, List<DwNavigationTarget>> targets = const {},
}) {
  final states = knownStates.toList();
  for (var zone = 0; zone < navigationZones.length; zone++) {
    for (final route in navigationZones[zone]) {
      final routeTargets =
          targets[route] ??
          [
            DwNavigationTarget(
              uri: Uri.parse(route.fullPath),
              routeName: route.name,
            ),
          ];
      final guards = route.zoneGuards;
      for (final target in routeTargets) {
        for (final known in states) {
          for (var index = 0; index < guards.length; index++) {
            final guard = guards[index];
            if (guard(known, target).redirectPath == null) {
              continue;
            }
            for (final field in nullableFields.entries) {
              final unknown = guard(field.value(known), target);
              if (!unknown.isPending && unknown.redirectPath == null) {
                throw StateError(
                  'Zone $zone, route ${route.name}, guard $index allows '
                  '${target.location} with ${field.key} unknown, but a known '
                  'value redirects. Return DwGuardDecision.pending.',
                );
              }
            }
          }
        }
      }
    }
  }
}
