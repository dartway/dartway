import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';

import 'delivery/dw_push_cleanup.dart';
import 'delivery/dw_push_worker.dart';
import 'dw_push_devices.dart';
import 'dw_push_message.dart';
import 'dw_push_migrations.dart';
import 'dw_push_settings.dart';
import 'providers/dw_push_provider.dart';

/// Push notifications on a DartWay server.
///
/// ```dart
/// DwAppServer(
///   protocol: DwWireProtocol(dwPushProtocolEntries, include: appProtocol),
///   modules: [
///     DwPushModule(
///       providers: [DwFcmProvider(account: DwFcmServiceAccount.fromJson(json))],
///       eligibility: (ctx, notice, accountIds) async => {...},
///     ),
///   ],
///   ...
/// );
///
/// // in a command, in its transaction:
/// await ctx.push.send(memberIds,
///     message: DwPushMessage(title: post.title, data: NewsAlert(id: post.id), link: '/news'),
///     category: ExamplePushCategory.news,
///     dedupKey: 'news:${post.id}');
/// ```
///
/// It brings the `push` tables, the `DwRegisterPushToken` and
/// `DwUnregisterPushToken` handlers, the delivery job (`dw.push.deliver`) and
/// the cleanup job (`dw.push.cleanup`). How delivery works is described on
/// the worker: claims in short transactions, provider calls outside any.
final class DwPushModule extends DwServerModule {
  DwPushModule({
    required List<DwPushProvider> providers,
    this.eligibility,
    this.settings = const DwPushSettings(),
  }) : _providers = List.unmodifiable(providers);

  /// The delivery job: drains due deliveries within a run budget.
  static final DwJobKind<void> deliverJob = DwJobKind.withoutPayload(
    'dw.push.deliver',
  );

  /// The recurring cleanup job.
  static const String cleanupJob = 'dw.push.cleanup';

  final List<DwPushProvider> _providers;

  /// Decides, when deliveries fall due, who is sent to now, skipped or
  /// delayed. Without it every recipient is sent to.
  final DwPushEligibility? eligibility;

  final DwPushSettings settings;

  /// The provider of each transport; a device of a transport without one is
  /// recorded as rejected with that reason.
  late final Map<DwPushTransport, DwPushProvider> providers = {
    for (final provider in _providers) provider.transport: provider,
  };

  late final DwPushWorker _worker = DwPushWorker(this);

  @override
  String get namespace => dwPushNamespace;

  @override
  List<DwDatabaseMigration> get migrations => dwPushMigrations;

  @override
  late final List<DwCallHandler> handlers = DwPushDevices(settings).handlers();

  @override
  late final List<DwJobDefinition> jobs = [
    DwQueuedJob(
      deliverJob,
      // Provider calls happen here: never inside the claiming transaction.
      transactional: false,
      lease: settings.lease,
      handle: (ctx, _) => _worker.run(ctx),
    ),
    DwRecurringJob(
      cleanupJob,
      every: settings.cleanupInterval,
      handle: (ctx) => DwPushCleanup(settings).run(ctx),
    ),
  ];

  @override
  List<String> problems(DwWireProtocol protocol) => [
    ...settings.problems,
    for (final type in [DwRegisterPushToken, DwUnregisterPushToken])
      if (!protocol.knows(type))
        'push: the protocol does not register $type — build it as '
            'DwWireProtocol(dwPushProtocolEntries, include: appProtocol)',
    for (final transport in DwPushTransport.values)
      if (_providers.where((p) => p.transport == transport).length > 1)
        'push: more than one provider for ${transport.name}',
  ];

  @override
  Future<void> close() async {
    for (final provider in _providers) {
      await provider.close();
    }
  }
}
