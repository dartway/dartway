import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_example_shared/generated/dw_protocol.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';

/// The protocol the app and the server speak: the generated one, the push
/// module's token registration calls, and the analytics module's calls.
final DwWireProtocol appProtocol = DwWireProtocol([
  ...dwPushProtocolEntries,
  ...dwAnalyticsProtocolEntries,
], include: dartwayExampleProtocol);
