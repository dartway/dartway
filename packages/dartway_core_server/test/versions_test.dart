import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// A server whose contract is `0.5.2`: an app compiled with an older breaking
/// line, or one that does not say, is told to update — on calls and on the
/// live socket (#296). The same line, older or newer within it, is served,
/// and so is a newer line: the server is the one behind then.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      protocol: DwWireProtocol(
        const [],
        include: testProtocol,
        contractVersion: '0.5.2',
      ),
    ),
  );

  Future<DwTestAnswer> callWith(String? contract) => harness().caller().call(
    const ListNotes(ownerId: -1),
    headers: {DwHttpContract.contractVersionHeader: contract},
  );

  test('an older breaking line is 426 dw.updateRequired', () async {
    final answer = await callWith('0.4.9');
    expect(answer.status, 426);
    expect(answer.response, isA<DwApiIncompatible>());
    expect(answer.refusal.isCode(DwCoreRefusal.updateRequired), isTrue);
  });

  test(
    'no contract version at all is as old as a client can be: 426',
    () async {
      final answer = await callWith(null);
      expect(answer.status, 426);
      expect(answer.refusal.isCode(DwCoreRefusal.updateRequired), isTrue);
    },
  );

  test('the same line is served, whichever side is ahead within it', () async {
    expect((await callWith('0.5.0')).status, 200);
    expect((await callWith('0.5.7')).status, 200);
  });

  test('a newer line is not told to update: the server is behind', () async {
    expect((await callWith('0.6.0')).status, 200);
  });

  test('a malformed contract version is a malformed call', () async {
    expect((await callWith('five')).status, 400);
  });

  test('the version is checked before the call is even known', () async {
    final answer = await harness().caller().raw(
      'POST',
      '/dw/NoSuchCall',
      headers: {
        DwHttpContract.protocolHeader: '$dwProtocolVersion',
        DwHttpContract.contractVersionHeader: '0.4.0',
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

    test('an old contract, or none named', () async {
      final server = harness().server;
      expect(await closeOf(server.liveEndpointWith(contract: '0.4.0')), (
        DwCloseCode.incompatible,
        'dw.updateRequired',
      ));
      expect(await closeOf(server.liveEndpointWith(withoutContract: true)), (
        DwCloseCode.incompatible,
        'dw.updateRequired',
      ));
    });

    test('another protocol, or none named', () async {
      final server = harness().server;
      for (final protocol in ['${dwProtocolVersion + 1}', null]) {
        expect(await closeOf(server.liveEndpointWith(protocol: protocol)), (
          DwCloseCode.incompatible,
          'dw.protocolUnsupported',
        ));
      }
    });

    test('a malformed contract version is a protocol error', () async {
      expect(
        await closeOf(harness().server.liveEndpointWith(contract: 'five')),
        (DwCloseCode.protocolError, 'dw.protocol'),
      );
    });

    test('a current app is greeted', () async {
      final socket = await harness().server.openLive(
        endpoint: harness().server.liveEndpointWith(),
      );
      expect(socket.connectionId, isNotEmpty);
      await socket.close();
    });
  });
}
