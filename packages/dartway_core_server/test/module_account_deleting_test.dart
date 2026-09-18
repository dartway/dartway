import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// A module holds things of its own for a person — a provider's refresh token
/// to revoke, a device to unregister — and the account's deletion is where it
/// lets go of them.
void main() {
  final module = _RecordingModule();
  final harness = useHarness(
    build: (app, config) => app.server(config, modules: [module]),
  );

  setUp(() {
    module.told.clear();
    module.refuse = false;
  });

  Future<int> accountOf(String email) async =>
      (await harness().app.signIn(harness().caller(), email)).id;

  test('every module is told, in the deleting transaction, while the account '
      'is still there to name', () async {
    final id = await accountOf('module-told@example.com');
    expect(await harness().server.server.accounts.deleteAccount(id), isTrue);
    expect(module.told, [id]);
    expect(
      module.sawAccount,
      isTrue,
      reason: 'the hook runs before the account row is gone',
    );
  });

  test('a module that refuses keeps the account: the deletion is one '
      'transaction, not a sequence of them', () async {
    final id = await accountOf('module-refuses@example.com');
    module.refuse = true;
    await expectLater(
      harness().server.server.accounts.deleteAccount(id),
      throwsA(isA<StateError>()),
    );
    expect(
      await harness().db.query(
        'SELECT 1 FROM dw_account WHERE id = @id',
        params: {'id': id},
      ),
      isNotEmpty,
      reason: 'nothing of the account may be gone when the module said no',
    );
    expect(
      await harness().db.query(
        'SELECT 1 FROM dw_auth_key WHERE account_id = @id AND revoked_at IS NULL',
        params: {'id': id},
      ),
      isNotEmpty,
      reason: 'its sessions are untouched too',
    );
  });

  test('a deletion with no server in this process tells no module, and says '
      'so in the documentation rather than pretending', () async {
    final id = await accountOf('module-detached@example.com');
    final detached = DwAccountService(harness().db, harness().app.auth());
    expect(await detached.deleteAccount(id), isTrue);
    expect(module.told, isEmpty);
  });
}

final class _RecordingModule extends DwServerModule {
  final List<int> told = [];
  bool refuse = false;
  bool sawAccount = false;

  @override
  String get namespace => 'test_module';

  @override
  Future<void> accountDeleting(DwCallContext ctx, int accountId) async {
    told.add(accountId);
    sawAccount = (await ctx.db.query(
      'SELECT 1 FROM dw_account WHERE id = @id',
      params: {'id': accountId},
    )).isNotEmpty;
    if (refuse) throw StateError('the module says no');
  }
}
