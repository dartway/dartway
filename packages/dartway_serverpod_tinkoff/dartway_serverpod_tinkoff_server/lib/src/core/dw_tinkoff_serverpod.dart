import 'package:serverpod/serverpod.dart';

import '../web/dw_tinkoff_webhook_route.dart';
import 'dw_tinkoff_api_service.dart';

class DwTinkoffServerpod {
  static init({
    required Serverpod serverpod,
    required String tinkoffWebRoutePathSegment,
    required DwOnPaymentProcessedCallback onPaymentConfirmed,
    DwPaymentUpdatesFilter? paymentUpdatesFilter,
    DwOnPaymentProcessedCallback? onPaymentRefunded,
  }) {
    final route = tinkoffWebRoutePathSegment[0] == '/'
        ? tinkoffWebRoutePathSegment
        : '/$tinkoffWebRoutePathSegment';

    print('Initializing Tinkoff Serverpod with route: $route');

    serverpod.webServer.addRoute(
      DwTinkoffWebhookRoute(
        onConfirmed: onPaymentConfirmed,
        filter: paymentUpdatesFilter,
        onRefunded: onPaymentRefunded,
      ),
      route,
    );

    DwTinkoffService.init(serverpod.server.passwords);
  }
}
