import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// A member's own profile, on a real client against the real server.
void main() {
  late AppHarness club;

  setUpAll(() async => club = await AppHarness.start());
  tearDownAll(() => club.stop());

  test('signing up creates the profile, named at registration', () async {
    final vera = await club.signUp('+7 999 000-00-10', firstName: 'Vera');
    final profile = await vera.client.fetch(const GetMyProfile());
    expect(profile.valueOrThrow.firstName, 'Vera');
    expect(profile.valueOrThrow.role, UserRole.client);
    expect(profile.valueOrThrow.accountId, vera.accountId);
    expect(profile.valueOrThrow.phone, '79990000010');
  });

  test('a member changes the phone they sign in with by code, without signing '
      'in again; the profile on screen follows', () async {
    final nina = await club.signUp('79990000070', firstName: 'Nina');
    final profile = nina.client.watch(const GetMyProfile());
    addTearDown(profile.close);
    await dwWaitUntil(() => profile.isLive);

    final ticket = await nina.client.command(
      const DwRequestIdentifierCode(
        kind: DwIdentifierKind.phone,
        identifier: '+7 999 000-00-71',
      ),
    );
    final identity = await nina.client.command(
      DwConfirmIdentifier(
        ticketId: ticket.valueOrThrow.id,
        code: club.delivered['79990000071']!,
        replace: true,
      ),
    );
    expect(identity.valueOrThrow.value, '79990000071');
    expect(identity.valueOrThrow.accountId, nina.accountId);
    expect(dataOf(profile.state)!.phone, '79990000071');

    final accounts = club.server.server.accounts;
    expect(
      await accounts.find(DwIdentifierKind.phone, '79990000071'),
      nina.accountId,
    );
    expect(await accounts.find(DwIdentifierKind.phone, '79990000070'), isNull);
  });
}
