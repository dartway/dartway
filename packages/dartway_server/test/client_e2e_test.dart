import 'package:dartway_client/dartway_client.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();
  const fast = DwClientOptions(
    callTimeout: Duration(seconds: 10),
    reconnectDelay: Duration(milliseconds: 50),
    releaseDelay: Duration.zero,
  );

  Future<DwSession> signIn(DwClient client, String identifier) async {
    final ticket = await client.command(
      DwRequestCode(kind: DwIdentifierKind.email, identifier: identifier),
    );
    final code = harness().app.delivered[identifier]!;
    final session = await client.command(
      DwVerifyCode(ticketId: ticket.valueOrNull!.id, code: code),
    );
    await client.signIn(session.valueOrNull!);
    return session.valueOrNull!;
  }

  test('a DwClient signs in, watches a live request and sees another '
      "client's command arrive; signing out ends the session", () async {
    final alice = await harness().server.connectClient(options: fast);
    final bob = await harness().server.connectClient(options: fast);
    final aliceSession = await signIn(alice, 'alice-e2e@example.com');
    await signIn(bob, 'bob-e2e@example.com');
    expect(alice.accountId, aliceSession.id);

    final watch = alice.watch(const LiveNotes());
    final states = <DwRequestState<List<NoteView>>>[];
    final subscription = watch.states.listen(states.add);
    await eventually(
      () => states.any((s) => s is DwRequestData<List<NoteView>> && s.live),
    );

    final created = await bob.command(const CreateNote('from bob'));
    final note = created.valueOrNull!;
    await eventually(
      () => states.any(
        (s) => s is DwRequestData<List<NoteView>> && s.value.contains(note),
      ),
    );

    final refused = await alice.command(const CreateNote(''));
    expect(refused, isA<DwRefused<NoteView>>());

    await alice.signOut();
    expect(alice.accountId, isNull);
    final afterSignOut = await alice.fetch(const MyNotes());
    expect(afterSignOut, isA<DwNotAuthenticated<List<NoteView>>>());

    await subscription.cancel();
    watch.close();
    await alice.stop();
    await bob.stop();
  });
}
