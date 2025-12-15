import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:project_name_server/src/generated/protocol.dart';

final waterIntakeCrudConfig = DwCrudConfig<WaterIntake>(
  table: WaterIntake.t,
  getListConfig: DwGetListConfig(),
  saveConfig: DwSaveConfig<WaterIntake>(
    allowSave: (session, initialModel, newModel) async =>
        session.isUser(newModel.userProfileId),
  ),
  deleteConfig: DwDeleteConfig<WaterIntake>(
    allowDelete: (session, model) async => session.isUser(model.userProfileId),
  ),
);
