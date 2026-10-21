import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// What a call took, in the server's own log: the per-endpoint latency a
/// proxy log cannot attribute to a handler.
void main() {
  List<String> linesOf(int from, String name) => [
    for (final line in RecordingLogger.lines.sublist(from))
      if (line.contains('call $name ')) line,
  ];

  group('under the threshold', () {
    final harness = useHarness();

    test('a call is one debug line: name, status, time, answer size', () async {
      final from = RecordingLogger.lines.length;
      final answer = await harness().caller().call(
        const ListNotes(ownerId: -1),
      );
      expect(answer.status, 200);
      final lines = linesOf(from, 'ListNotes');
      expect(lines, hasLength(1));
      expect(
        lines.single,
        matches(
          RegExp(r'^debug +call ListNotes status=200 ms=\d+\.\d bytes=\d+$'),
        ),
      );
      final bytes = int.parse(lines.single.split('bytes=').last);
      expect(bytes, answer.text.length);
    });

    test('a refused call is timed too, with its status', () async {
      final from = RecordingLogger.lines.length;
      expect((await harness().caller().call(const MyNotes())).status, 401);
      expect(linesOf(from, 'MyNotes').single, contains('status=401'));
    });
  });

  group('over the threshold', () {
    final harness = useHarness(
      build: (app, database) => app.server(
        database,
        settings: const DwServerSettings(slowCallThreshold: Duration.zero),
      ),
    );

    test(
      'a call is a warning, whatever the level, and names the threshold',
      () async {
        final from = RecordingLogger.lines.length;
        expect(
          (await harness().caller().call(const ListNotes(ownerId: -1))).status,
          200,
        );
        final lines = linesOf(from, 'ListNotes');
        expect(lines, hasLength(1));
        expect(
          lines.single,
          matches(
            RegExp(
              r'^warning +slow call ListNotes status=200 ms=\d+\.\d bytes=\d+ '
              r'\(over 0 ms\)$',
            ),
          ),
        );
      },
    );
  });
}
