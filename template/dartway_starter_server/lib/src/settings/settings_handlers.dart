import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/core/call_context.dart';
import 'package:dartway_starter_server/src/core/channels.dart';
import 'package:dartway_starter_server/src/settings/settings_rows.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

final settingsHandlers = <DwCallHandler>[
  /// Every app setting. Every signed-in member.
  DwCallHandler.list<ListAppSettings, AppSetting>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.appSettings.find(
        orderBy: (t) => [t.key.asc()],
      ))
        AppSetting(id: row.key, value: row.value),
    ],
  ),

  /// Writes an app setting. Admins only; published to every member.
  DwCallHandler.command<SaveAppSetting, AppSetting>(
    access: AppAccess.admin,
    handle: (ctx, command) async {
      final existing = await ctx.db.appSettings.findFirst(
        where: (t) => t.key.equals(command.key),
        lock: DwRowLock.forUpdate,
      );
      final saved = existing == null
          ? await ctx.db.appSettings.insert(
              AppSettingRow(key: command.key, value: command.value),
            )
          : await ctx.db.appSettings.update(
              existing.copyWith(value: command.value),
            );
      final setting = AppSetting(id: saved.key, value: saved.value);
      ctx.publish(AppChannels.settings, setting);
      return setting;
    },
  ),
];
