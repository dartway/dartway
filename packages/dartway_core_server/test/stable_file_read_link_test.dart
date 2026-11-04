import 'package:test/test.dart';

import 'support/files.dart';
import 'support/test_app.dart';

/// Stable server-owned links use a controlled clock without changing the real
/// clock used by upload tickets, code tickets, or recurring jobs elsewhere.
void main() {
  final clock = DwTestClock(DateTime.utc(2026, 11, 4, 23, 59));
  late TestStorage storage;
  setUpAll(() async => storage = await TestStorage.create());
  tearDownAll(() async => storage.drop());

  final harness = useFilesHarness(
    () => storage,
    clock: clock,
    declaration: (config) => testStorage(config),
  );

  late DwTestCaller alice;
  setUpAll(() async {
    (alice, _) = await harness().signedIn('stable-files-alice@example.com');
  });

  Future<DwStoredFile> uploadDocument() async {
    final command = DwStartUpload(
      purpose: TestUpload.document,
      fileName: 'stable.txt',
      contentType: 'text/plain',
      byteSize: 40,
    );
    final ticket = (await alice.call(command)).value(command);
    final put = await putToTicket(ticket, bytesOf(40, 4));
    expect(put.status, 200, reason: put.body);
    final finish = DwFinishUpload(ticketId: ticket.id);
    return (await alice.call(finish)).value(finish);
  }

  test('stable readLink is day-signed and browser-cacheable', () async {
    final file = await uploadDocument();

    Future<DwFileLink> stableLink() => harness().server.runInContext(
      (ctx) async => (await ctx.files.readLink(file.id, stable: true))!,
    );

    final first = await stableLink();
    clock.moveTo(DateTime.utc(2026, 11, 4, 23, 59, 59));
    final sameDay = await stableLink();
    expect(sameDay.url, first.url);
    expect(first.expiresAt, DateTime.utc(2026, 11, 6));
    expect(
      first.expiresAt!.difference(clock.now()),
      greaterThanOrEqualTo(const Duration(hours: 24)),
    );
    expect(
      Uri.parse(first.url).queryParameters['response-cache-control'],
      'private, max-age=86400, immutable',
    );
    expect(first.url, contains('response-cache-control=private%2C%20'));

    clock.moveTo(DateTime.utc(2026, 11, 5));
    final nextDay = await stableLink();
    expect(nextDay.url, isNot(first.url));
    expect(nextDay.expiresAt, DateTime.utc(2026, 11, 7));
  });

  test('stable readLink refuses an explicit expiry', () async {
    expect(
      () => harness().server.runInContext(
        (ctx) => ctx.files.readLink(
          1 << 40,
          stable: true,
          expires: const Duration(hours: 1),
        ),
      ),
      throwsArgumentError,
    );
  });
}
