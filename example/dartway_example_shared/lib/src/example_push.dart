import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';

import '../generated/dw_protocol.dart';

/// The example's kinds of notification. The server's eligibility rule reads
/// them: news goes only to members who agreed to marketing.
enum ExamplePushCategory with DwPushCategory {
  /// A news post was published.
  news,
}

/// The protocol the app and the server speak: the generated one, and the push
/// module's token registration calls.
final DwWireProtocol exampleProtocol = DwWireProtocol(
  dwPushProtocolEntries,
  include: dartwayExampleProtocol,
);
