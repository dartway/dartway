import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

import 'package:dartway_push_server/testing.dart';

import 'support/push_harness.dart';

void main() {
  final harness = usePushHarness();

  setUp(() {
    final h = harness();
    h.fcm.answer = (_) => const DwFakePushAnswer.ok();
    h.fcm.delay = Duration.zero;
    h.fcm.gate = null;
    h.rustore.answer = (_) => const DwFakePushAnswer.ok();
    h.eligibility = null;
  });

  Future<DwResultRow> deliveryOf(int accountId) async =>
      (await harness().db.query(
        'SELECT * FROM dw_push_delivery WHERE account_id = @a '
        'ORDER BY id DESC LIMIT 1',
        params: {'a': accountId},
      )).single;

  Future<void> finished(int accountId) => eventually(
    () async => (await deliveryOf(accountId))['finished_at'] != null,
  );

  test(
    'a push queued in a committed command reaches FCM in its wire format',
    () async {
      final h = harness();
      final member = await h.member('fcm-token-wire');
      final answer = await h.queue(QueueAlert(recipients: [member.id]));
      expect(answer.value(QueueAlert(recipients: const [])), 1);
      await finished(member.id);

      final delivery = await deliveryOf(member.id);
      expect(delivery['outcome'], 'sent');
      expect(delivery['attempts'], 0);
      final send = h.fcm.sends.singleWhere((s) => s.token == 'fcm-token-wire');
      expect(send.path, '/v1/projects/test-project/messages:send');
      expect(send.authorization, 'Bearer ${h.fcm.lastAccessToken}');
      expect(send.contentType, 'application/json');
      final message = send.message;
      expect(message['notification'], {
        'title': 'Pool closed',
        'body': 'Maintenance day.',
      });
      expect(message['data'], {
        'dw_type': 'NewsAlert',
        'dw_payload': jsonEncode({'id': 12, 'title': 'Pool closed'}),
        'dw_link': '/news/12',
      });
      // The typed payload comes back through the protocol, as an app reads it.
      expect(
        DwPushData.fromWire(message['data']! as Map, testProtocol).payload,
        const NewsAlert(id: 12, title: 'Pool closed'),
      );
      final webpush = message['webpush']! as Map;
      expect(webpush['fcm_options'], {
        'link': 'https://app.example.com/news/12',
      });
      expect((message['android']! as Map)['ttl'], matches(RegExp(r'^\d+s$')));
    },
  );

  test('an https image goes to FCM; an http one is left out and the command '
      'still commits', () async {
    // An http image is what a development storage's public URL is: the
    // notification is decoration-free there, not a failed command.
    final h = harness();
    for (final (token, image, shown) in [
      ('fcm-token-https-image', 'https://cdn.example.com/a.png', true),
      ('fcm-token-http-image', 'http://127.0.0.1:9000/public/a.png', false),
    ]) {
      final member = await h.member(token);
      final command = QueueAlert(recipients: [member.id], image: image);
      expect((await h.queue(command)).value(command), 1);
      await finished(member.id);
      expect((await deliveryOf(member.id))['outcome'], 'sent');
      final notification =
          h.fcm.sends
                  .singleWhere((s) => s.token == token)
                  .message['notification']!
              as Map;
      expect(notification.containsKey('image'), shown, reason: image);
      if (shown) expect(notification['image'], image);
      expect(
        h.logs.any((line) => line.contains('push image $image is not https')),
        !shown,
        reason: 'an image left out is said, not silent',
      );
    }
  });

  test('an image that is not an http URL at all is a mistake, and queues '
      'nothing', () async {
    final h = harness();
    final member = await h.member('fcm-token-bad-image');
    final command = QueueAlert(recipients: [member.id], image: 'ftp://x/a.png');
    expect((await h.queue(command)).status, 500);
    expect(
      await h.db.query(
        'SELECT 1 FROM dw_push_delivery WHERE account_id = @a',
        params: {'a': member.id},
      ),
      isEmpty,
    );
    h.alerts.incidents.clear();
  });

  test('a push queued in a rolled-back command does not exist', () async {
    final h = harness();
    final member = await h.member('fcm-token-rollback');
    final before = (await h.db.query(
      'SELECT count(*) AS n FROM dw_push_message',
    )).single['n'];
    final answer = await h.queue(
      QueueAlert(recipients: [member.id], refuse: true),
    );
    expect(answer.status, 409);
    expect(
      (await h.db.query(
        'SELECT count(*) AS n FROM dw_push_message',
      )).single['n'],
      before,
    );
    expect(
      await h.db.query(
        'SELECT 1 FROM dw_push_delivery WHERE account_id = @a',
        params: {'a': member.id},
      ),
      isEmpty,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(h.fcm.sends.where((s) => s.token == 'fcm-token-rollback'), isEmpty);
  });

  test('a dedup key sends once per recipient', () async {
    final h = harness();
    final member = await h.member('fcm-token-dedup');
    final other = await h.member('fcm-token-dedup-other');
    const key = 'news:12';
    final first = await h.queue(
      QueueAlert(recipients: [member.id], dedupKey: key),
    );
    expect(first.value(QueueAlert(recipients: const [])), 1);
    await finished(member.id);
    // Retried after delivery, and together with a new recipient.
    final second = await h.queue(
      QueueAlert(recipients: [member.id, other.id, member.id], dedupKey: key),
    );
    expect(second.value(QueueAlert(recipients: const [])), 1);
    await finished(other.id);
    final third = await h.queue(
      QueueAlert(recipients: [member.id, other.id], dedupKey: key),
    );
    expect(third.value(QueueAlert(recipients: const [])), 0);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      h.fcm.sends.where((s) => s.token == 'fcm-token-dedup'),
      hasLength(1),
    );
    expect(
      h.fcm.sends.where((s) => s.token == 'fcm-token-dedup-other'),
      hasLength(1),
    );
  });

  test('eligibility skips a recipient without calling the provider', () async {
    final h = harness();
    final skipped = await h.member('fcm-token-skipped');
    final allowed = await h.member('fcm-token-allowed');
    final asked = <(String, List<int>)>[];
    h.eligibility = (ctx, notice, accountIds) async {
      asked.add((notice.category, accountIds));
      expect(notice.isOf(TestCategory.news), isTrue);
      expect(
        notice.data.payload,
        const NewsAlert(id: 12, title: 'Pool closed'),
      );
      return {
        for (final id in accountIds)
          if (id == skipped.id) id: DwPushDecision.skip,
      };
    };
    await h.queue(QueueAlert(recipients: [skipped.id, allowed.id]));
    await finished(skipped.id);
    await finished(allowed.id);
    expect((await deliveryOf(skipped.id))['outcome'], 'skipped');
    expect((await deliveryOf(allowed.id))['outcome'], 'sent');
    expect(
      asked.single.$2,
      unorderedEquals([skipped.id, allowed.id]),
      reason: 'one call per message per batch',
    );
    expect(h.fcm.sends.where((s) => s.token == 'fcm-token-skipped'), isEmpty);
  });

  test('eligibility delays a recipient and is asked again when due', () async {
    final h = harness();
    final member = await h.member('fcm-token-delayed');
    var asked = 0;
    late DateTime until;
    h.eligibility = (ctx, notice, accountIds) async {
      asked++;
      if (asked == 1) {
        until = DateTime.now().add(const Duration(milliseconds: 700));
        return {member.id: DwPushDecision.delayUntil(until)};
      }
      return const {};
    };
    await h.queue(QueueAlert(recipients: [member.id]));
    await eventually(() => asked == 1);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final waiting = await deliveryOf(member.id);
    expect(waiting['finished_at'], isNull);
    expect(
      (waiting['run_at']! as DateTime).difference(until).inMilliseconds.abs(),
      lessThan(2),
    );
    expect(h.fcm.sends.where((s) => s.token == 'fcm-token-delayed'), isEmpty);
    await finished(member.id);
    expect(asked, 2);
    expect((await deliveryOf(member.id))['outcome'], 'sent');
    expect(
      DateTime.now().isAfter(until),
      isTrue,
      reason: 'sent only once the delay passed',
    );
  });

  test(
    'an eligibility answer about another account fails the run loudly',
    () async {
      final h = harness();
      final member = await h.member('fcm-token-bad-rule');
      var calls = 0;
      h.eligibility = (ctx, notice, accountIds) async {
        if (calls++ == 0) return {-1: DwPushDecision.skip};
        return const {};
      };
      await h.queue(QueueAlert(recipients: [member.id]));
      await eventually(
        () => h.logs.any((l) => l.contains('answered for accounts it was not')),
      );
      // The job is retried by the queue's backoff; its claim was rolled back,
      // so nothing was recorded.
      expect((await deliveryOf(member.id))['outcome'], isNull);
    },
  );

  test(
    'a provider failure is recorded with its text and retried with backoff',
    () async {
      final h = harness();
      final member = await h.member('fcm-token-flaky');
      var calls = 0;
      h.fcm.answer = (send) {
        if (send.token != 'fcm-token-flaky') return const DwFakePushAnswer.ok();
        return calls++ == 0
            ? DwFakePushAnswer.fcmError(
                503,
                'UNAVAILABLE',
                'The server is temporarily unavailable.',
                fcmCode: 'UNAVAILABLE',
              )
            : const DwFakePushAnswer.ok();
      };
      await h.queue(QueueAlert(recipients: [member.id]));
      await eventually(
        () async => (await deliveryOf(member.id))['attempts'] == 1,
      );
      final failed = await deliveryOf(member.id);
      expect(
        failed['last_error'],
        'fcm device ${(await h.devices()).firstWhere((d) => d['token'] == 'fcm-token-flaky')['id']}: '
        'fcm 503 UNAVAILABLE: The server is temporarily unavailable.',
      );
      expect(failed['finished_at'], isNull);
      await finished(member.id);
      final done = await deliveryOf(member.id);
      expect(done['outcome'], 'sent');
      expect(done['attempts'], 1, reason: 'one failed attempt, counted once');
      expect(calls, 2);
    },
  );

  test(
    'a network failure is recorded with the error text, not its type',
    () async {
      final h = harness();
      final member = await h.account();
      await h.register(
        member,
        'rustore-token-down',
        transport: DwPushTransport.rustore,
      );
      h.rustore.dropConnections = true;
      addTearDown(() => h.rustore.dropConnections = false);
      await h.queue(QueueAlert(recipients: [member.id]));
      await eventually(
        () async => (await deliveryOf(member.id))['attempts'] == 1,
      );
      final error = (await deliveryOf(member.id))['last_error']! as String;
      expect(error, startsWith('rustore device '));
      expect(error, contains('rustore send failed: HttpException'));
      expect(
        error,
        contains('Connection closed before full header was received'),
      );
      // Out of attempts: failed, with the text kept, and an error logged.
      await eventually(
        () async => (await deliveryOf(member.id))['outcome'] == 'failed',
      );
      expect((await deliveryOf(member.id))['attempts'], 3);
      expect(
        h.logs.any(
          (l) => l.startsWith('error') && l.contains('failed: rustore device'),
        ),
        isTrue,
      );
    },
  );

  test(
    'an invalid token removes only that transport\'s registration',
    () async {
      final h = harness();
      final member = await h.account();
      const token = 'shared-token-string';
      await h.register(member, token);
      await h.register(
        member,
        token,
        transport: DwPushTransport.rustore,
        platform: DwPushPlatform.android,
      );
      h.fcm.answer = (send) => send.token == token
          ? DwFakePushAnswer.fcmError(
              404,
              'NOT_FOUND',
              'Requested entity was not found.',
              fcmCode: 'UNREGISTERED',
            )
          : const DwFakePushAnswer.ok();
      await h.queue(QueueAlert(recipients: [member.id]));
      await finished(member.id);
      final delivery = await deliveryOf(member.id);
      expect(
        delivery['outcome'],
        'sent',
        reason: 'RuStore accepted it: ${delivery['last_error']}',
      );
      expect(delivery['last_error'], contains('token invalid, removed'));
      expect(delivery['last_error'], contains('UNREGISTERED'));
      final remaining = [
        for (final d in await h.devices())
          if (d['account_id'] == member.id) d['transport'],
      ];
      expect(remaining, ['rustore']);
      expect(h.rustore.sends.where((s) => s.token == token), hasLength(1));
      expect(
        h.rustore.sends.last.path,
        '/v1/projects/rustore-project/messages:send',
      );
      expect(
        h.rustore.sends.last.authorization,
        'Bearer rustore-service-token',
      );
    },
  );

  test('a device signed out anywhere receives nothing', () async {
    final h = harness();
    final member = await h.member('fcm-token-signed-out');
    await h.server.server.accounts.revokeKey(member.keyId);
    await h.queue(QueueAlert(recipients: [member.id]));
    await finished(member.id);
    expect((await deliveryOf(member.id))['outcome'], 'noDevices');
    expect(
      h.fcm.sends.where((s) => s.token == 'fcm-token-signed-out'),
      isEmpty,
    );
  });

  test('a delivery past its lifetime expires unsent', () async {
    final h = harness();
    final member = await h.member('fcm-token-expired');
    h.eligibility = (ctx, notice, accountIds) async => {
      for (final id in accountIds)
        id: DwPushDecision.delayUntil(
          DateTime.now().add(const Duration(hours: 1)),
        ),
    };
    await h.queue(QueueAlert(recipients: [member.id], lifetimeMillis: 60000));
    await finished(member.id);
    expect((await deliveryOf(member.id))['outcome'], 'expired');
    expect(h.fcm.sends.where((s) => s.token == 'fcm-token-expired'), isEmpty);
  });

  test('a device that settled is never sent the delivery again', () async {
    final h = harness();
    final member = await h.account();
    await h.register(member, 'two-devices-a');
    await h.register(member, 'two-devices-b');
    var failuresOfB = 0;
    h.fcm.answer = (send) {
      if (send.token == 'two-devices-b' && failuresOfB++ == 0) {
        return DwFakePushAnswer.fcmError(
          429,
          'RESOURCE_EXHAUSTED',
          'Quota exceeded.',
          fcmCode: 'QUOTA_EXCEEDED',
          headers: {'retry-after': '1'},
        );
      }
      return const DwFakePushAnswer.ok();
    };
    await h.queue(QueueAlert(recipients: [member.id]));
    await eventually(
      () async => (await deliveryOf(member.id))['attempts'] == 1,
    );
    final waiting = await deliveryOf(member.id);
    final wait = (waiting['run_at']! as DateTime).difference(
      waiting['created_at']! as DateTime,
    );
    expect(
      wait,
      greaterThanOrEqualTo(const Duration(milliseconds: 900)),
      reason: 'Retry-After (1 s) wins over the 200 ms backoff',
    );
    await finished(member.id);
    expect(h.fcm.sends.where((s) => s.token == 'two-devices-a'), hasLength(1));
    expect(h.fcm.sends.where((s) => s.token == 'two-devices-b'), hasLength(2));
  });
}
