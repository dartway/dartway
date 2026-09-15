import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';
import 'package:meta/meta.dart';

import 'dw_push_settings.dart';

/// The handlers of the device registration commands.
@internal
final class DwPushDevices {
  const DwPushDevices(this.settings);

  final DwPushSettings settings;

  List<DwCallHandler> handlers() => [
    DwCallHandler.command<DwRegisterPushToken, void>(
      access: DwAccessRule.signedIn,
      handle: _register,
    ),
    DwCallHandler.command<DwUnregisterPushToken, void>(
      access: DwAccessRule.signedIn,
      handle: _unregister,
    ),
  ];

  /// One statement: the token is taken by the caller (and the key the call
  /// was signed in with) whoever had it — `ON CONFLICT` makes two devices
  /// racing on one token wait for each other instead of aborting — and the
  /// caller's least recently registered devices beyond the limit go.
  ///
  /// The eviction reads the table as it was before the statement, so it
  /// keeps the newest `max - 1` of the caller's *other* devices.
  Future<void> _register(DwCallContext ctx, DwRegisterPushToken command) async {
    final key = ctx.sessionKey!;
    await ctx.db.execute(
      'WITH registered AS ('
      'INSERT INTO dw_push_device (account_id, key_id, transport, token, platform) '
      'VALUES (@account, @key, @transport, @token, @platform) '
      'ON CONFLICT (transport, token) DO UPDATE SET '
      'account_id = EXCLUDED.account_id, key_id = EXCLUDED.key_id, '
      'platform = EXCLUDED.platform, updated_at = now() RETURNING id) '
      'DELETE FROM dw_push_device WHERE id IN ('
      'SELECT id FROM dw_push_device WHERE account_id = @account '
      'AND NOT (transport = @transport AND token = @token) '
      'ORDER BY updated_at DESC, id DESC OFFSET @keep) '
      'AND id NOT IN (SELECT id FROM registered)',
      params: {
        'account': key.accountId,
        'key': key.id,
        'transport': command.transport.name,
        'token': command.token,
        'platform': command.platform.name,
        'keep': settings.maxDevicesPerAccount - 1,
      },
    );
  }

  Future<void> _unregister(
    DwCallContext ctx,
    DwUnregisterPushToken command,
  ) async {
    await ctx.db.execute(
      'DELETE FROM dw_push_device WHERE account_id = @account AND token = @token',
      params: {'account': ctx.requireAccountId, 'token': command.token},
    );
  }
}
