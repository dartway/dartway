import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/testing.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness club;
  late DwFakePushService fcm;

  setUpAll(() async {
    fcm = await DwFakePushService.start();
    club = await AppHarness.start(
      push: AppPush.module(
        providers: [
          fcm.fcmProvider(webLinkBase: Uri.parse('https://app.example.com')),
        ],
      ),
    );
  });

  tearDownAll(() async {
    await club.stop();
    await fcm.close();
  });

  Future<void> registerDevice(AppMember member, String token) async {
    final result = await member.client.command(
      DwRegisterPushToken(
        transport: DwPushTransport.fcm,
        token: token,
        platform: DwPushPlatform.android,
      ),
    );
    expect(result, isA<DwCallOk<void>>());
  }

  test('a published post notifies the members who agreed to marketing, once, '
      'with the post and a link to the news', () async {
    final coach = await club.withRole(
      '+7 999 100 00 01',
      'Boris',
      UserRole.staff,
      marketing: true,
    );
    final agreed = await club.signUp(
      '+7 999 100 00 02',
      firstName: 'Vera',
      marketing: true,
    );
    final declined = await club.signUp('+7 999 100 00 03', firstName: 'Oleg');
    await registerDevice(coach, 'coach-device');
    await registerDevice(agreed, 'agreed-device');
    await registerDevice(declined, 'declined-device');

    const publish = PublishNews(title: 'Pool closed', text: 'Maintenance day.');
    final post = (await coach.client.command(publish)).valueOrThrow;
    // A retried publication with a new key would be a new post; the same post
    // notified twice is what the dedup key prevents.

    Future<Map<int, String?>> outcomes() async => {
      for (final row in await club.db.query(
        'SELECT account_id, outcome FROM dw_push_delivery',
      ))
        row['account_id']! as int: row['outcome'] as String?,
    };
    await dwWaitUntil(
      () async => (await outcomes()).values.every((o) => o != null),
    );
    expect(await outcomes(), {
      agreed.accountId: 'sent',
      declined.accountId: 'skipped',
    }, reason: 'the author is not notified of their own post');

    final send = fcm.sends.single;
    expect(send.token, 'agreed-device');
    expect((send.message['notification']! as Map)['title'], 'Pool closed');
    final data = DwPushData.fromWire(send.message['data']! as Map, appProtocol);
    expect(data.payload, NewsAlert(id: post.id));
    expect(data.link, '/news');
    expect(
      ((send.message['webpush']! as Map)['fcm_options']! as Map)['link'],
      'https://app.example.com/news',
    );
  });

  test('a refused publication notifies nobody', () async {
    final member = await club.signUp(
      '+7 999 100 00 04',
      firstName: 'Anna',
      marketing: true,
    );
    await registerDevice(member, 'refused-device');
    final before = fcm.sends.length;
    final result = await member.client.command(
      const PublishNews(title: 'Not staff', text: 'Refused.'),
    );
    expect(result, isA<DwCallRefused<NewsPost>>());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(fcm.sends, hasLength(before));
  });
  test('a booked session reminds its member two hours before it starts; a '
      'booking cancelled by then reminds nobody', () async {
    final service = await club.db.clubServices.insert(
      const NewClubServiceRow(
        title: 'Morning yoga',
        description: 'Mats provided',
        durationMinutes: 60,
        price: 1500,
      ),
    );
    final session = await club.db.clubSessions.insert(
      NewClubSessionRow(
        serviceId: service.id,
        startsAt: club.clock.now().add(const Duration(days: 1)),
        capacity: 5,
      ),
    );
    final keeps = await club.signUp('+7 999 100 00 05', firstName: 'Ivan');
    final cancels = await club.signUp('+7 999 100 00 06', firstName: 'Olga');
    await registerDevice(keeps, 'keeps-device');
    await registerDevice(cancels, 'cancels-device');
    final kept = (await keeps.client.command(
      BookSession(sessionId: session.id),
    )).valueOrThrow;
    final cancelled = (await cancels.client.command(
      BookSession(sessionId: session.id),
    )).valueOrThrow;
    (await cancels.client.command(
      CancelBooking(bookingId: cancelled.id),
    )).valueOrThrow;

    // One reminder queued per booking, due two hours before the session.
    Future<List<Map<String, Object?>>> reminders() async => [
      for (final row in await club.db.query(
        "SELECT key, run_at FROM dw_job WHERE name = 'bookings.remind' "
        'ORDER BY id',
      ))
        {'key': row['key'], 'runAt': row['run_at']},
    ];
    final queued = await reminders();
    expect(
      [for (final job in queued) job['key']],
      ['bookings.remind:${kept.id}', 'bookings.remind:${cancelled.id}'],
    );
    expect(
      (queued.first['runAt']! as DateTime).isAtSameMomentAs(
        session.startsAt.subtract(const Duration(hours: 2)),
      ),
      isTrue,
    );

    // The time comes — the server's clock reaches it, which wakes the jobs:
    // both run, and only the active booking reminds.
    final before = fcm.sends.length;
    club.clock.moveTo(queued.first['runAt']! as DateTime);
    await dwWaitUntil(() async => (await reminders()).isEmpty);
    await dwWaitUntil(() => fcm.sends.length > before);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final reminder = fcm.sends.skip(before).single;
    expect(reminder.token, 'keeps-device');
    expect((reminder.message['notification']! as Map)['title'], 'Morning yoga');
  });
  test('a reminder that runs after its session started sends nothing', () async {
    final service = await club.db.clubServices.insert(
      const NewClubServiceRow(
        title: 'Evening stretch',
        description: 'Mats provided',
        durationMinutes: 45,
        price: 1200,
      ),
    );
    final session = await club.db.clubSessions.insert(
      NewClubSessionRow(
        serviceId: service.id,
        startsAt: club.clock.now().add(const Duration(days: 1)),
        capacity: 5,
      ),
    );
    final late = await club.signUp('+7 999 100 00 07', firstName: 'Igor');
    await registerDevice(late, 'late-device');
    final booking = (await late.client.command(
      BookSession(sessionId: session.id),
    )).valueOrThrow;

    // The queue fell behind — the server was down past the reminder's time:
    // by the time the job runs, the session is on.
    final before = fcm.sends.length;
    club.clock.moveTo(session.startsAt.add(const Duration(minutes: 5)));
    await dwWaitUntil(
      () async => (await club.db.query(
        "SELECT 1 FROM dw_job WHERE key = 'bookings.remind:${booking.id}'",
      )).isEmpty,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(fcm.sends, hasLength(before));
  });
}
