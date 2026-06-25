import 'package:dartway_example_client/dartway_example_client.dart';

import 'dw_core.dart';

/// Convenience access to the raw Serverpod client. Most code should go through
/// `dw` and `DwRepository`; use this only for direct endpoint calls (e.g. the
/// development endpoint).
class AppCore {
  static Client get serverpodClient => dw.client;
}
