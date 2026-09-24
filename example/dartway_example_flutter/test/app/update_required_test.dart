import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('an app on an older contract line than the server is told to '
      'update, over the whole app', (tester) async {
    // A server whose contract moved to a breaking line this build predates.
    final club = FakeClub()..server.contractVersion = '99.0.0';
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
