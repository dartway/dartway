import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import '../call_context.dart';
import '../channels.dart';
import '../entities/settings.dart';

final settingsHandlers = <DwCallHandler>[
  DwCallHandler.list<ListAppSettings, AppSetting>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.appSettings.find(
        orderBy: (t) => [t.key.asc()],
      ))
        AppSetting(id: row.key, value: row.value),
    ],
  ),

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
      ctx.publish(settingsChannel, setting);
      return setting;
    },
  ),
];
