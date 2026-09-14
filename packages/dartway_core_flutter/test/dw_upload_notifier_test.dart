import 'dart:typed_data';

import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/rooms.dart';

enum AppUpload with DwUploadPurpose { avatar }

const alice = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);

/// An avatar picker as an app would write one: a button, a line of state.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker(this.dw, this.bytes, {super.key});

  final DwFlutterCore dw;
  final Uint8List bytes;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  late final DwUploadNotifier avatar = widget.dw.uploader();

  @override
  void dispose() {
    avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DwUploadState>(
    valueListenable: avatar,
    builder: (context, state, _) => Column(
      children: [
        Text(switch (state) {
          DwUploadIdle() => 'idle',
          DwUploadProgress(:final fraction) =>
            'uploading ${(fraction * 100).round()}%',
          DwUploadDone(:final file) => 'done ${file.fileName} #${file.id}',
          DwUploadError(:final refusal?) => 'refused ${refusal.code}',
          DwUploadError(:final error) => 'error ${error.runtimeType}',
        }),
        TextButton(
          onPressed: avatar.isBusy
              ? null
              : () => avatar.upload(
                  AppUpload.avatar,
                  DwUploadSource.bytes(widget.bytes),
                  fileName: 'me.jpg',
                  contentType: 'image/jpeg',
                ),
          child: const Text('upload'),
        ),
      ],
    ),
  );
}

void main() {
  late DwFakeServer server;
  late DwFakeStorage storage;
  late List<DwErrorReport> reports;

  DwFlutterCore core() => DwFlutterCore(
    config: DwConfig(
      appVersion: '1.0.0+1',
      onErrorReport: reports.add,
      refusalText: (refusal) => refusal.code,
    ),
    protocol: roomsProtocol,
    baseUrl: server.baseUrl,
    httpTransport: server.httpTransport,
    liveConnector: server.liveConnector,
    storageTransport: storage.transport,
    tokenStore: DwMemoryTokenStore(alice),
    clientOptions: dwFakeClientOptions,
  );

  setUp(() {
    server = DwFakeServer(protocol: roomsProtocol)
      ..registerToken(alice.token, alice.id);
    storage = DwFakeStorage(server);
    reports = [];
  });

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 400; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 5));
    }
    fail('never found $finder');
  }

  Uint8List bytes(int size) =>
      Uint8List.fromList(List.generate(size, (i) => i & 0xff));

  testWidgets('a widget follows the upload from idle through progress to the '
      'file', (tester) async {
    final dw = core();
    await dw.init();
    storage.chunkDelay = const Duration(milliseconds: 5);
    final body = bytes(256 * 1024);

    await tester.pumpWidget(MaterialApp(home: AvatarPicker(dw, body)));
    expect(find.text('idle'), findsOneWidget);

    await tester.tap(find.text('upload'));
    await tester.pump();
    expect(find.text('uploading 0%'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
      reason: 'busy while uploading',
    );

    await pumpUntil(
      tester,
      find.textContaining(RegExp(r'uploading [1-9]\d?%')),
    );
    await pumpUntil(tester, find.text('done me.jpg #1'));
    expect(storage.objects[1]!.bytes, body);
    expect(reports, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets('a refusal is a state the screen renders, not a report', (
    tester,
  ) async {
    final dw = core();
    await dw.init();
    storage.refuseStart = (command) => DwCallRefusal(
      DwUploadRefusal.tooLarge,
      field: 'byteSize',
      params: {'maxBytes': 10},
    );
    await tester.pumpWidget(MaterialApp(home: AvatarPicker(dw, bytes(11))));
    await tester.tap(find.text('upload'));
    await pumpUntil(tester, find.text('refused dw.uploadTooLarge'));
    expect(storage.puts, 0);
    expect(reports, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets('storage refusing the bytes is an error state and a report; '
      'the slot resets and uploads again', (tester) async {
    final dw = core();
    await dw.init();
    storage.answerStatuses.add(403);
    final notifier = dw.uploader();
    addTearDown(notifier.dispose);
    final states = <DwUploadState>[];
    notifier.addListener(() => states.add(notifier.value));

    final pending = notifier.upload(
      AppUpload.avatar,
      DwUploadSource.bytes(bytes(8)),
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
    );
    expect(notifier.isBusy, isTrue);
    expect(
      () => notifier.upload(
        AppUpload.avatar,
        DwUploadSource.bytes(bytes(8)),
        fileName: 'b.jpg',
        contentType: 'image/jpeg',
      ),
      throwsStateError,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(await pending, isNull);
    final error = notifier.value as DwUploadError;
    expect(
      error.error,
      isA<DwUploadException>().having(
        (e) => e.failure,
        'failure',
        DwUploadFailure.rejected,
      ),
    );
    expect(reports.single.error, same(error.error));

    notifier.reset();
    expect(notifier.value, const DwUploadIdle());
    final retried = notifier.upload(
      AppUpload.avatar,
      DwUploadSource.bytes(bytes(8)),
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    final file = await retried;
    expect(file, isNotNull);
    expect(notifier.value, DwUploadDone(file!));
    expect(states.first, const DwUploadProgress(0, 8));
    expect(states, contains(const DwUploadProgress(8, 8)));

    await dw.dispose();
  });

  testWidgets('a network that stays down until the ticket expires is shown, '
      'not reported', (tester) async {
    final dw = core();
    await dw.init();
    storage
      // Expired at once: the first attempt is still made, and its failure
      // ends the upload — without waiting on a wall clock in fake time.
      ..ticketLifetime = Duration.zero
      ..failPuts = 1 << 20;
    final notifier = dw.uploader();
    addTearDown(notifier.dispose);
    final pending = notifier.upload(
      AppUpload.avatar,
      DwUploadSource.bytes(bytes(8)),
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
    );
    for (var i = 0; i < 100 && notifier.isBusy; i++) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    expect(await pending, isNull);
    expect(
      (notifier.value as DwUploadError).error,
      isA<DwUploadException>().having(
        (e) => e.failure,
        'failure',
        DwUploadFailure.unreachable,
      ),
    );
    expect(reports, isEmpty);
    await dw.dispose();
  });
}
