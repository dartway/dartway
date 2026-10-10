import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

const _notes = DwLiveChannel(TestChannel.notes);
const _public = DwLiveChannel(TestChannel.public);
const _oldObject = NoteView(id: 504, text: 'known');
const _newObject = IssuedKey(id: 504, token: 'new');
final _newMatch = isA<IssuedKey>()
    .having((o) => o.id, 'id', 504)
    .having((o) => o.token, 'token', 'new');
const _deletion = DwDeletedObject(typeName: 'IssuedKey', id: 505);

DwWireProtocol protocolAt(String version, {bool includeNew = true}) =>
    DwWireProtocol([
      for (final entry in testProtocol.entries)
        if (entry.type != IssuedKey) entry,
      if (includeNew)
        DwProtocolEntry<IssuedKey>(
          'IssuedKey',
          IssuedKey.fromJson,
          since: DwContractVersion('13.1.0'),
        ),
    ], contractVersion: version);

void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      protocol: protocolAt('13.1.0'),
      handlers: [
        for (final handler in app.handlers())
          if (handler.callType != Ping && handler.callType != PublishAndEnd)
            handler,
        DwCallHandler.command<Ping, String>(
          access: DwAccessRule.signedIn,
          handle: (ctx, command) async {
            ctx
              ..publish(_notes, _oldObject)
              ..publish(_notes, _newObject)
              ..publish(_notes, _deletion)
              ..publish(_public, _newObject);
            return 'pong';
          },
        ),
        DwCallHandler.command<PublishAndEnd, void>(
          access: DwAccessRule.signedIn,
          handle: (ctx, command) async {
            ctx
              ..publish(_notes, _newObject)
              ..publish(_notes, _deletion);
          },
        ),
      ],
    ),
  );

  for (final version in ['13.0.0', '13.1.0']) {
    test(
      'response at $version carries only known groups, including deletions',
      () async {
        final (caller, _) = await harness().signedIn(
          'updates-$version@example.com',
        );
        final answer = await caller.call(
          const Ping(),
          headers: {DwHttpContract.contractVersionHeader: version},
        );
        expect(answer.status, 200);
        final response = answer.response as DwApiOk;
        expect(
          response.updates.objectsOn('notes'),
          version == '13.0.0'
              ? [_oldObject]
              : [_oldObject, _newMatch, _deletion],
        );
        expect(
          response.updates.channels.containsKey('public'),
          version == '13.1.0',
        );
        if (version == '13.0.0') {
          // An installed protocol has no entry for the new group. The actual
          // response must decode through the strict reader without error.
          final oldProtocol = protocolAt(version, includeNew: false);
          final decoded =
              DwApiResponse.fromJson(answer.json, oldProtocol) as DwApiOk;
          expect(
            decoded.toResult(const Ping(), oldProtocol).valueOrNull,
            'pong',
          );
          expect(decoded.updates.objectsOn('notes'), [_oldObject]);
          // Strictness still catches a server that leaks an unknown group.
          expect(
            () => DwChannelUpdates.fromJson({
              'IssuedKey': [_newObject.toJson()],
            }, oldProtocol),
            throwsFormatException,
          );
          expect(
            () => DwChannelUpdates.fromJson({
              'DwDeletedObject': [_deletion.toJson()],
            }, oldProtocol),
            throwsFormatException,
          );
          final empty = await caller.call(
            const PublishAndEnd('ok'),
            headers: {DwHttpContract.contractVersionHeader: version},
          );
          expect((empty.response as DwApiOk).updates.isEmpty, isTrue);
        }
      },
    );
  }

  test(
    'an installed client without the new entry completes an existing command',
    () async {
      final (_, session) = await harness().signedIn(
        'installed-client@example.com',
      );
      final client = DwAppClient(
        protocol: protocolAt('13.0.0', includeNew: false),
        baseUrl: harness().server.httpBase,
        appVersion: '1.0.0+1',
        options: dwTestClientOptions,
      );
      addTearDown(client.stop);
      await client.start();
      await client.signIn(session);
      final result = await client.command(const Ping());
      expect(result, isA<DwCallOk<String>>());
      expect(result.valueOrNull, 'pong');
    },
  );

  test(
    'live connections filter per build and suppress empty updates',
    () async {
      final (caller, session) = await harness().signedIn(
        'live-updates@example.com',
      );
      final server = harness().server;
      Future<DwTestLiveSocket> socketAt(String version) async {
        final socket = await server.openLive(
          endpoint: server.liveEndpointWith(contract: version),
        );
        addTearDown(socket.close);
        await socket.authenticate(session.token);
        expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
        return socket;
      }

      final old = await socketAt('13.0.0');
      final current = await socketAt('13.1.0');
      await caller.call(const Ping());
      expect((await old.expect<DwUpdateMessage>()).updates.objects, [
        _oldObject,
      ]);
      expect((await current.expect<DwUpdateMessage>()).updates.objects, [
        _oldObject,
        _newMatch,
        _deletion,
      ]);
      await caller.call(const PublishAndEnd('ok'));
      expect((await current.expect<DwUpdateMessage>()).updates.objects, [
        _newMatch,
        _deletion,
      ]);
      await old.expectSilence();
    },
  );

  test(
    'a protocol without a contract version does not filter introductions',
    () async {
      final unversioned = await Harness.start(
        build: (app, config) => app.server(
          config,
          protocol: DwWireProtocol([
            for (final entry in testProtocol.entries)
              if (entry.type != NoteView) entry,
            DwProtocolEntry<NoteView>(
              'NoteView',
              NoteView.fromJson,
              since: DwContractVersion('13.1.0'),
            ),
          ]),
        ),
      );
      addTearDown(unversioned.stop);
      final (caller, _) = await unversioned.signedIn('unversioned@example.com');
      final answer = await caller.call(
        const CreateNote('unversioned'),
        headers: {DwHttpContract.contractVersionHeader: '13.0.0'},
      );
      expect(answer.status, 200);
      expect(
        (answer.response as DwApiOk).updates.objectsOn('notes'),
        hasLength(1),
      );
    },
  );
}
