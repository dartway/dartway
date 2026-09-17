import 'package:dartway_client/dartway_client.dart';
import 'package:test/test.dart';

import 'support.dart';

/// `listen`: hearing a channel without reading anything — a badge counting
/// new posts has its count from a request and needs only the publications.
void main() {
  test('subscribes without a request and hears what is published', () async {
    final h = Harness()..serveRooms();
    await h.start();
    final heard = <DwWireObject>[];
    final subscription = h.client.listen([roomsChannel]).listen(heard.add);
    await settle();

    expect(h.server.subscriberCount(roomsChannel), 1);
    expect(h.server.requestsOf<ListRooms>(), isEmpty, reason: 'nothing read');

    h.server.publish(roomsChannel, [const RoomView(id: 5, name: 'new')]);
    await settle();
    expect(heard, [const RoomView(id: 5, name: 'new')]);

    await subscription.cancel();
    await settle();
    expect(h.server.unsubscribeCount(roomsChannel), 1);
    expect(h.server.openConnections, isEmpty);
  });

  test(
    'shares a channel with a watched request, and leaving keeps it',
    () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      final subscription = h.client.listen([roomsChannel]).listen((_) {});
      await settle();
      expect(h.server.subscribeCount(roomsChannel), 1, reason: 'one sub');

      await subscription.cancel();
      await settle();
      expect(h.server.unsubscribeCount(roomsChannel), 0);
      expect(watch.isLive, isTrue);
      watch.close();
    },
  );

  test('a caller channel follows a switch of account', () async {
    final h = Harness();
    await h.start();
    final heard = <DwWireObject>[];
    final subscription = h.client.listen([myNotesChannel]).listen(heard.add);
    await settle();
    final aliceNotes = DwLiveChannel.forAccount(AppChannel.notes, alice.id);
    final bobNotes = DwLiveChannel.forAccount(AppChannel.notes, bob.id);
    expect(h.server.subscriberCount(aliceNotes), 1);

    await h.client.signIn(bob);
    await settle();
    expect(h.server.subscriberCount(aliceNotes), 0);
    expect(h.server.subscriberCount(bobNotes), 1);

    h.server.publish(aliceNotes, [const NoteView(id: 1, text: 'for alice')]);
    h.server.publish(bobNotes, [const NoteView(id: 2, text: 'for bob')]);
    await settle();
    expect(heard, [const NoteView(id: 2, text: 'for bob')]);
    await subscription.cancel();
  });
}
