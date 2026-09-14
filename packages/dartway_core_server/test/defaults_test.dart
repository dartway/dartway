import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/defaults.dart';
import 'support/test_app.dart';

final defaultsProtocol = DwWireProtocol([
  const DwProtocolEntry<Compose>('Compose', $ComposeFromJson),
  const DwProtocolEntry<Echoes>('Echoes', $EchoesFromJson),
  const DwProtocolEntry<Echo>('Echo', $EchoFromJson),
], include: testProtocol);

/// D-041 over real HTTP: a call that leaves out fields with constructor
/// defaults is not malformed; the server applies the defaults.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      protocol: defaultsProtocol,
      handlers: [
        ...app.handlers(),
        DwCallHandler.command<Compose, String>(
          access: DwAccessRule.anonymous,
          handle: (ctx, command) async => [
            List.filled(command.times, command.text).join(command.separator),
            command.loud,
            command.tone.name,
            command.tags.join(','),
            command.limits.length,
            command.signature,
          ].join('|'),
        ),
        DwCallHandler.list<Echoes, Echo>(
          access: DwAccessRule.anonymous,
          handle: (ctx, request) async => [
            for (var i = 0; i < request.count; i++)
              Echo(id: i, label: i == 0 ? '' : '${request.prefix}$i'),
          ],
        ),
      ],
    ),
  );

  late DwTestCaller caller;
  setUpAll(() => caller = harness().caller());

  test('a raw command body without defaulted fields succeeds', () async {
    const command = Compose(text: 'hi');
    final answer = await caller.call(
      command,
      body: utf8.encode(jsonEncode({'text': 'hi'})),
    );
    expect(answer.status, 200, reason: answer.text);
    expect(answer.value(command), 'hi hi|false|plain|draft|0|team');
  });

  test('explicit values win over the defaults, null included', () async {
    const command = Compose(text: 'x');
    final answer = await caller.call(
      command,
      body: utf8.encode(
        jsonEncode({
          'text': 'x',
          'times': 3,
          'separator': '-',
          'loud': true,
          'tone': 'warm',
          'tags': <String>[],
          'limits': {'a': 1},
          'signature': null,
        }),
      ),
    );
    expect(answer.status, 200, reason: answer.text);
    expect(answer.value(command), 'x-x-x|true|warm||1|null');
  });

  test('the typed call sends only what differs from the defaults', () async {
    expect(const Compose(text: 'hi').toJson(), {'text': 'hi'});
    expect(const Compose(text: 'hi', signature: null).toJson(), {
      'text': 'hi',
      'signature': null,
    });
    const command = Compose(text: 'hi', times: 1);
    expect(
      (await caller.call(command)).value(command),
      'hi|false|plain|draft|0|team',
    );
  });

  test('a required field stays required: its absence is malformed', () async {
    final answer = await caller.call(
      const Compose(text: 'hi'),
      body: utf8.encode(jsonEncode({'times': 1})),
    );
    expect(answer.status, 400, reason: answer.text);
  });

  test('an empty request body is the request of its defaults, and a result '
      'omits its own defaults', () async {
    const request = Echoes();
    final answer = await caller.call(request, body: utf8.encode('{}'));
    expect(answer.status, 200, reason: answer.text);
    expect(answer.json, {
      'status': 'ok',
      'result': [
        {'id': 0},
        {'id': 1, 'label': 'echo1'},
        {'id': 2, 'label': 'echo2'},
      ],
    });
    expect(answer.value(request), const [
      Echo(id: 0),
      Echo(id: 1, label: 'echo1'),
      Echo(id: 2, label: 'echo2'),
    ]);
  });
}
