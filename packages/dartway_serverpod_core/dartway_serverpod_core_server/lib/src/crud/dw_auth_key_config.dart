import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';

final dwAuthKeyConfig = DwCrudConfig<DwAuthKey>(
  table: DwAuthKey.t,
  deleteConfig: DwDeleteConfig(
    allowDelete: (session, model) => session.isUser(model.userId),
  ),
);
