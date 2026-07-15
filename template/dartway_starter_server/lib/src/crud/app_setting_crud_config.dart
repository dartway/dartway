import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_starter_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_starter_server/src/generated/protocol.dart';

/// CRUD configuration for the AppSetting model (app branding and settings).
/// Everyone reads settings; only the admin writes, nobody deletes.
final appSettingCrudConfig = DwCrudConfig<AppSetting>(
  table: AppSetting.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
  ),
  saveConfig: DwSaveConfig<AppSetting>(
    allowSave: (session, saveContext) async => session.isClubAdmin,
    validateSave: (session, saveContext) async =>
        saveContext.currentModel.settingKey.trim().isEmpty
            ? 'Setting key is required'
            : null,
  ),
);
