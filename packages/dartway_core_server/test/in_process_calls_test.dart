import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  DwAppServer server() => harness().server.server;

  test('a request runs as the session of the token', () async {
    final (_, session) = await harness().signedIn('inproc-reader@example.com');
    await TestApp.insertNote(harness().db, 'read in process', session.id);

    final result = await server().callAs(const MyNotes(), token: session.token);
    expect(result.valueOrThrow.map((note) => note.text), ['read in process']);
  });

  test('a command is idempotent by its key, and its refusal is the same as '
      'over HTTP', () async {
    final (_, session) = await harness().signedIn('inproc-writer@example.com');

    final first = await server().callAs(
      const CreateNote('once'),
      token: session.token,
      idempotencyKey: 'inproc-1',
    );
    final again = await server().callAs(
      const CreateNote('once'),
      token: session.token,
      idempotencyKey: 'inproc-1',
    );
    expect(again.valueOrThrow, first.valueOrThrow);
    expect(
      (await harness().db.query(
        "SELECT count(*) AS n FROM note WHERE text = 'once'",
      )).single.get<int>('n'),
      1,
    );

    final invalid = await server().callAs(
      const CreateNote(''),
      token: session.token,
    );
    expect(
      invalid,
      isA<DwCallRefused<NoteView>>().having(
        (r) => r.refusal.field,
        'field',
        'text',
      ),
    );
  });

  test('an unknown or revoked token is not authenticated', () async {
    expect(
      await server().callAs(const MyNotes(), token: 'no-such-token'),
      isA<DwNotAuthenticated<List<NoteView>>>(),
    );
  });
}
