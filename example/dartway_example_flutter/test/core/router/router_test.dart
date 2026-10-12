import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_router/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all zone guards wait for nullable facts before allowing a target', () {
    dwCheckPendingGuards<AppRouterState>(
      navigationZones: [
        AppNavigationZone.values,
        AdminNavigationZone.values,
        AuthNavigationZone.values,
      ],
      knownStates: [
        for (final role in UserRole.values) (isSignedIn: true, role: role),
        (isSignedIn: false, role: null),
      ],
      nullableFields: {
        'role': (state) => (isSignedIn: state.isSignedIn, role: null),
      },
    );
  });
}
