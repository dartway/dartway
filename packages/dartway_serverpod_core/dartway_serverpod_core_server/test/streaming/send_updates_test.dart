import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/streaming_session_double.dart';

/// Where `session.sendUpdates` delivers — the routing half of broadcasting.
///
/// Worth pinning because a config answers with a *list* of channels, and an
/// update reaching one audience but silently not the other shows up only as
/// "it did not update on their screen", days later and on someone else's device.
///
/// The payload half (models wrapped, deletions marked) is not asserted here on
/// purpose: `DwModelWrapper` resolves the protocol through `Serverpod.instance`,
/// so wrapping a row needs a booted server. That path is exercised by the
/// database-backed suites in `template/` and `example/`, which run a real one.
void main() {
  late MessageCentral messageCentral;
  late FakeStreamingSession session;

  setUp(() {
    messageCentral = MessageCentral();
    session = FakeStreamingSession('sender', messageCentral);
  });

  /// Counts what arrives on [channel] for a listener of its own.
  List<SerializableModel> listenOn(String channel) {
    final received = <SerializableModel>[];
    final listener = FakeStreamingSession('listener-$channel', messageCentral);
    listener.messages.addListener(channel, received.add);
    return received;
  }

  test('every channel in the list is delivered to', () async {
    final catalogue = listenOn('catalogue');
    final moderators = listenOn('moderators');

    session.sendUpdates(channels: ['catalogue', 'moderators']);
    await pumpEventQueue();

    expect(catalogue, hasLength(1));
    expect(moderators, hasLength(1));
  });

  test('a channel nobody broadcast to gets nothing', () async {
    final other = listenOn('other');

    session.sendUpdates(channels: ['catalogue']);
    await pumpEventQueue();

    expect(other, isEmpty);
  });

  test('an empty channel list posts nothing at all', () async {
    final catalogue = listenOn('catalogue');

    session.sendUpdates(channels: []);
    await pumpEventQueue();

    expect(catalogue, isEmpty);
  });

  test('the same channel twice is delivered twice, not deduplicated', () async {
    // Not a nicety: a config that composes its channel list from two rules can
    // repeat one, and silently swallowing the second delivery would make the
    // count depend on how the list was built.
    final catalogue = listenOn('catalogue');

    session.sendUpdates(channels: ['catalogue', 'catalogue']);
    await pumpEventQueue();

    expect(catalogue, hasLength(2));
  });

  test('sendUpdatesToUser reaches that user and no one else', () async {
    final mine = listenOn(DwCoreConst.userUpdatesChannel(42));
    final theirs = listenOn(DwCoreConst.userUpdatesChannel(43));

    session.sendUpdatesToUser(42);
    await pumpEventQueue();

    expect(mine, hasLength(1));
    expect(theirs, isEmpty);
  });

  test('the public channel name is one string both sides can agree on', () {
    // The template subscribes to this exact constant at its app root; a rename
    // that only lands on one side would go unnoticed until nothing updates.
    expect(DwCoreConst.publicUpdatesChannel, 'dwPublicUpdates');
  });
}
