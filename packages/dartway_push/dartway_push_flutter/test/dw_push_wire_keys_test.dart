import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('push data keys', () {
    // Pinned against the literals, deliberately — not against the constants in
    // `dartway_push_server`, which the app half must not depend on. The two
    // halves of the module are held together by these strings, and a rename on
    // one side fails a test on the other instead of producing a notification
    // that arrives and shows nothing.
    test('are the wire contract with the server half', () {
      expect(dwPushTitleDataKey, 'push_title');
      expect(dwPushBodyDataKey, 'push_body');
      expect(dwPushImageUrlDataKey, 'image_url');
      expect(dwPushLinkDataKey, 'link');
    });
  });

  group('push provider identifiers', () {
    test('are the values this device reports at registration', () {
      expect(DwPushProviderIds.fcm, 'fcm');
      expect(DwPushProviderIds.ruStore, 'rustore');
    });
  });
}
