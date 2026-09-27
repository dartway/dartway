import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../generated/dw_protocol.dart';

/// The protocol the app and the server speak: the generated one, and the
/// analytics module's calls — the app's events, reports and dashboards.
final DwWireProtocol appProtocol = DwWireProtocol(
  dwAnalyticsProtocolEntries,
  include: dartwayStarterProtocol,
);
