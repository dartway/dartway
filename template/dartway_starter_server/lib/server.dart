import 'dart:io';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    show dwAuthenticationHandler;
import 'package:dartway_starter_server/src/web/routes/root.dart';
import 'package:serverpod/serverpod.dart';

import 'src/dartway/dartway_core.dart';
import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';

// This is the starting point of your Serverpod server. In most cases, you will
// only need to make additions to this file if you add future calls, are
// configuring Relic (Serverpod's web-server), or need custom setup work.

void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  // DartWay plugs its model-driven auth in via [dwAuthenticationHandler].
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: dwAuthenticationHandler,
  );

  // Setup a default page at the web root.
  pod.webServer.addRoute(RouteRoot(), '/');
  pod.webServer.addRoute(RouteRoot(), '/index.html');
  // Serve all files in the /web/static directory.
  pod.webServer.addRoute(StaticRoute.directory(Directory('web/static')), '/');

  initDartwayCore(passwords: pod.server.passwords);

  await pod.start();
}
