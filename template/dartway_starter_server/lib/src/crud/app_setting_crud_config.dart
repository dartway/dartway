import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_starter_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_starter_server/src/generated/protocol.dart';

/// CRUD configuration for the AppSetting model (app branding and settings).
/// Everyone reads settings; only the admin writes, nobody deletes.
final appSettingCrudConfig = DwCrudConfig<AppSetting>(
  table: AppSetting.t,
  getListConfig: DwGetModelListConfig(accessFilter: (session) async => null),
  saveConfig: DwSaveConfig<AppSetting>(
    allowSave: (session, saveContext) async => session.isAdmin,
    validateSave: (session, saveContext) async =>
        saveContext.currentModel.settingKey.trim().isEmpty
        ? 'Setting key is required'
        : null,
    // Settings are the same for everyone, so a change belongs on every screen at
    // once: the admin renames the app and the home screen updates for every
    // signed-in user, with no refresh and no listener written anywhere. The app
    // subscribes to this channel once, at its root.
    //
    // Safe to broadcast precisely because this model has no per-user reading —
    // its accessFilter grants the whole audience. A model scoped to its owner
    // would leak here; that one notifies its owner instead.
    broadcastTo: (session, saveContext) => [DwCoreConst.publicUpdatesChannel],
  ),
);
