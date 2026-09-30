import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

/// The staff channels are the chat feature's seed step: every start writes
/// them, and a start with nothing new writes nothing (#388).
void main() {
  late DwTestDatabase database;

  setUp(() async {
    database = await DwTestDatabase.create(prefix: 'dw_example_test');
  });
  tearDown(() => database.drop());

  /// The channels after a start; [then] runs on the started server after
  /// they are read.
  Future<Map<String, (int, String)>> startedChannels({
    Future<void> Function(DwTestServer server)? then,
  }) async {
    return AppHarness.onDatabase(database, (server) async {
      final channels = {
        for (final row in await server.db.chatChannels.find())
          row.slug: (row.id, row.title),
      };
      await then?.call(server);
      return channels;
    });
  }

  test('a fresh database starts with the declared channels, and the next '
      'start keeps the very same rows', () async {
    final first = await startedChannels();
    expect(first.keys, [for (final channel in staffChannels) channel.slug]);
    expect(first['front-desk']!.$2, 'Front desk');

    expect(await startedChannels(), first, reason: 'same ids, same titles');
  });

  test('a title edited by hand goes back to the declared one', () async {
    final first = await startedChannels(
      then: (server) => server.db.execute(
        "UPDATE chat_channel SET title = 'Reception' WHERE slug = 'front-desk'",
      ),
    );
    final restarted = await startedChannels();
    expect(
      restarted['front-desk'],
      first['front-desk'],
      reason: 'the declaration wins over a hand edit, keeping the id',
    );
  });
}
