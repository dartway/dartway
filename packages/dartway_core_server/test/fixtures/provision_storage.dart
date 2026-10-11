import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';

Future<void> main(List<String> args) async {
  if (args.single == 'test-storage') {
    await DwTestStorage.create();
  } else {
    await DwFileStorageSetup.provision(
      DwFileStorageConfig.fromEnvironment(Platform.environment),
      allowedOrigins: ['https://app.example'],
    );
  }
}
