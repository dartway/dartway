import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/testing.dart';
import 'package:test/test.dart';

import 'support/club_harness.dart';

void main() {
  late ClubHarness club;
  late DwFakePushService fcm;

  setUpAll(() async {
    fcm = await DwFakePushService.start();
    club = await ClubHarness.start(
      push: examplePush(
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

  Future<void> registerDevice(ClubMember member, String token) async {
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
    final coach = await club.memberWithRole(
      '+7 999 100 00 01',
      'Boris',
      UserRole.staff,
      marketing: true,
    );
    final agreed = await club.member(
      '+7 999 100 00 02',
      'Vera',
      marketing: true,
    );
    final declined = await club.member('+7 999 100 00 03', 'Oleg');
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
    await eventually(
      () async => (await outcomes()).values.every((o) => o != null),
    );
    expect(await outcomes(), {
      agreed.accountId: 'sent',
      declined.accountId: 'skipped',
    }, reason: 'the author is not notified of their own post');

    final send = fcm.sends.single;
    expect(send.token, 'agreed-device');
    expect((send.message['notification']! as Map)['title'], 'Pool closed');
    final data = DwPushData.fromWire(
      send.message['data']! as Map,
      exampleProtocol,
    );
    expect(data.payload, NewsAlert(id: post.id));
    expect(data.link, '/news');
    expect(
      ((send.message['webpush']! as Map)['fcm_options']! as Map)['link'],
      'https://app.example.com/news',
    );
  });

  test('a refused publication notifies nobody', () async {
    final member = await club.member(
      '+7 999 100 00 04',
      'Anna',
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
}
