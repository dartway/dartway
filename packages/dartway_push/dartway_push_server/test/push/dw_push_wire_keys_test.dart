import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

void main() {
  group('push data keys', () {
    // Pinned against the literals, deliberately — not against the constants in
    // `dartway_push_flutter`, which the server must not depend on. The two
    // halves of the module are held together by these strings, and a rename on
    // one side fails a test on the other instead of producing a notification
    // that arrives and shows nothing.
    test('are the wire contract with the app half', () {
      expect(dwPushTitleDataKey, 'push_title');
      expect(dwPushBodyDataKey, 'push_body');
      expect(dwPushImageUrlDataKey, 'image_url');
    });
  });

  group('push provider identifiers', () {
    test('are the values a device reports at registration', () {
      expect(DwPushProviders.fcm, 'fcm');
      expect(DwPushProviders.ruStore, 'rustore');
    });
  });
}
