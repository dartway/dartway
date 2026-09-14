import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('a build below the server minimum is told to update, over the '
      'whole app', (tester) async {
    final club = FakeClub()..server.minAppBuild = 2;
    // Mounted as the app runner mounts it: the framework's bootstrapper, not a
    // copy of what it does.
    final app = await ExampleTestApp.start(tester, club, bootstrap: true);

    expect(
      app.core.client.incompatibility?.isCode(DwCoreRefusal.updateRequired),
      isTrue,
    );
    expect(find.text('Update the app'), findsOneWidget);
    expect(find.text('Welcome!'), findsNothing);
    expect(find.text('Schedule'), findsNothing);

    await app.stop(tester);
  });
}
