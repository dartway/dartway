import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/src/system_info/system_info_routes.dart';

/// A signed-in diagnostic door demonstrating both external seams.
final systemInfoFeature = DwServerFeature(
  'system_info',
  routes: systemInfoRoutes,
);
