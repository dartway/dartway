import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';
import '../../support/app_harness.dart';

void main() {
  test(
    'project config adopts link confirmation without signing in the landing browser',
    () async {
      Uri? deliveredLink;
      final harness = await AppHarness.start(
        attachDelivery: {
          DwIdentifierKind.phone: DwIdentifierLinkPolicy(
            urlTemplate: 'https://example.com/#/confirm?token={token}',
            replace: true,
            deliverLink: (ctx, kind, identifier, link) async =>
                deliveredLink = link,
          ),
        },
      );
      addTearDown(harness.stop);
      final member = await harness.signUp('+79990000127', firstName: 'Member');
      await member.client.command(
        const DwRequestIdentifierCode(
          kind: DwIdentifierKind.phone,
          identifier: '+79990000128',
        ),
      );
      final landing = await harness.client();
      final token = Uri.parse(
        deliveredLink!.fragment,
      ).queryParameters['token']!;
      final result = await landing.client.command(
        DwConfirmIdentifierLink(token: token),
      );
      expect(result, isA<DwCallOk<void>>());
      expect(landing.client.accountId, isNull);
    },
  );
}
