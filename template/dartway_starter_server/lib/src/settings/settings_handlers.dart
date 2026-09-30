import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/src/core/call_context.dart';
import 'package:dartway_starter_server/src/core/channels.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

final settingsHandlers = <DwCallHandler>[
  /// The app's settings, their defaults while nobody has saved them. Every
  /// signed-in member.
  DwCallHandler.single<GetAppSettings, AppSettings>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) => ctx.settings.read<AppSettings>(),
  ),

  /// Changes the settings the command names, the rest as they are. Admins
  /// only; published to every member.
  DwCallHandler.command<SaveAppSettings, AppSettings>(
    access: AppAccess.admin,
    handle: (ctx, command) async {
      final saved = await ctx.settings.update<AppSettings>(
        (current) => current.copyWith(
          appName: command.appName?.trim(),
          signUpEnabled: command.signUpEnabled,
        ),
      );
      ctx.publish(AppChannels.settings, saved);
      return saved;
    },
  ),
];
