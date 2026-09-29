import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_app.dart';

void main() {
  testWidgets('signing out through the core ends the session', (tester) async {
    final app = await TestApp.start(tester, FakeApp());
    expect(app.core.client.accountId, testSession.id);
    await app.run(tester, app.core.signOut());
    expect(app.core.client.accountId, isNull);
    await app.stop(tester);
  });
}
