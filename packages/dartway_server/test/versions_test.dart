import 'package:dartway_server/dartway_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// `DwServerSettings.minAppBuild` above 0: an app older than it, or one that
/// does not say, is told to update — on calls and on the live socket.
void main() {
  final harness = useHarness(
    build: (app, config) =>
        app.server(config, settings: const DwServerSettings(minAppBuild: 5)),
  );

  Future<DwTestAnswer> callWith(String? version) => harness().caller().call(
    const ListNotes(ownerId: -1),
    headers: {DwHttpContract.appVersionHeader: version},
  );

  test('a build below the minimum is 426 dw.updateRequired', () async {
    final answer = await callWith('2.3.0+4');
    expect(answer.status, 426);
    expect(answer.response, isA<DwApiIncompatible>());
    expect(answer.refusal.isCode(DwCoreRefusal.updateRequired), isTrue);
  });

  test('no version at all is as old as a client can be: 426', () async {
    final answer = await callWith(null);
    expect(answer.status, 426);
    expect(answer.refusal.isCode(DwCoreRefusal.updateRequired), isTrue);
  });

  test('the minimum build and above are served', () async {
    expect((await callWith('0.1.0+5')).status, 200);
    expect((await callWith('9.0.0-beta.1+120')).status, 200);
  });

  test('the version is checked before the call is even known', () async {
    final answer = await harness().caller().raw(
      'POST',
      '/dw/NoSuchCall',
      headers: {
        DwHttpContract.protocolHeader: '1',
        DwHttpContract.appVersionHeader: '1.0.0+1',
      },
    );
    expect(answer.status, 426);
  });

  group('the live socket closes with the incompatible code', () {
    Future<(int?, String?)> closeOf(Uri endpoint) async {
      final socket = await harness().server.openLive(
        endpoint: endpoint,
        awaitHello: false,
      );
      final code = await socket.closeCode;
      expect(socket.frames, isEmpty, reason: 'no hello before the close');
      return (code, socket.closeReason);
    }

    test('an old app, or none named', () async {
      final server = harness().server;
      expect(await closeOf(server.liveEndpointWith(app: '1.0.0+4')), (
        DwCloseCode.incompatible,
        'dw.updateRequired',
      ));
      expect(await closeOf(server.liveEndpointWith(app: null)), (
        DwCloseCode.incompatible,
        'dw.updateRequired',
      ));
    });

    test('another protocol, or none named', () async {
      final server = harness().server;
      for (final protocol in ['2', null]) {
        expect(
          await closeOf(
            server.liveEndpointWith(protocol: protocol, app: '1.0.0+5'),
          ),
          (DwCloseCode.incompatible, 'dw.protocolUnsupported'),
        );
      }
    });

    test('a malformed app version is a protocol error', () async {
      expect(await closeOf(harness().server.liveEndpointWith(app: 'five')), (
        DwCloseCode.protocolError,
        'dw.protocol',
      ));
    });

    test('a current app is greeted', () async {
      final socket = await harness().server.openLive(
        endpoint: harness().server.liveEndpointWith(app: '1.0.0+5'),
      );
      expect(socket.connectionId, isNotEmpty);
      await socket.close();
    });
  });
}
