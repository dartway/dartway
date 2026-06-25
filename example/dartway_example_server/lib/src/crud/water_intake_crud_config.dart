import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

final waterIntakeCrudConfig = DwCrudConfig<WaterIntake>(
  table: WaterIntake.t,
  getListConfig: DwGetModelListConfig<WaterIntake>(
    accessFilter: (session) async => null,
  ),
  saveConfig: DwSaveConfig<WaterIntake>(
    allowSave: (session, saveContext) async =>
        session.isUser(saveContext.currentModel.userProfileId),
  ),
  deleteConfig: DwDeleteConfig<WaterIntake>(
    allowDelete: (session, model) async => session.isUser(model.userProfileId),
  ),
);
