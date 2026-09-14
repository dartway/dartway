import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dw_flutter.dart';
import '../core/logic/dw_config.dart';
import '../core/logic/dw_key_value_store.dart';
import '../diagnostics/error_reporting/logic/dw_error_source.dart';
import '../private/dw_singleton.dart';
import 'dw_key_value_token_store.dart';
import 'dw_request_notifiers.dart';

/// The app core with the data layer: the toolbox of [DwFlutter] plus one
/// [DwAppClient] and the Riverpod bindings over it.
///
/// ```dart
/// late final DwFlutterCore dw;
///
/// dw = DwFlutterCore(
///   config: DwConfig(
///     appVersion: '1.4.2+57',
///     refusalText: (refusal) => t.refusal(refusal),
///     updateRequiredScreen: (context, refusal) => const UpdateTheAppPage(),
///   ),
///   protocol: appProtocol,
///   baseUrl: Uri.parse('https://api.example.com'),
///   plugins: [DwSharedPreferences()],
/// );
/// DwAppRunner(appInitializers: [dw.init], child: const App()).run();
///
/// ref.watch(dw.request(const ListUpcomingSessions()));  // AsyncValue<List<ClubSession>>
/// ref.watch(dw.pages(const FeedPosts()));               // AsyncValue<DwPagedData<FeedPost>>
/// ref.watch(dw.table(const ListClients(page: 2)));      // AsyncValue<DwTablePage<ClientCard>>
/// ref.watch(dw.window(const ReadChat(chatId: 7)));      // AsyncValue<DwWindowData<ChatMessage>>
/// await dw.command(BookSession(sessionId: 3));          // DwCallResult<SessionBooking>
/// ref.watch(dw.accountId);                              // int?
/// ```
///
/// Two phases: the constructor builds and connects nothing; [init] starts the
/// plugins, then the client. [dispose] stops the client and releases the
/// core, after which another can be built — nothing here is static.
class DwFlutterCore extends DwFlutter {
  /// Throws [ArgumentError] for a config without `refusalText` or
  /// `appVersion`, and whatever [DwAppClient] throws for a malformed app
  /// version or base URL — in every case before the core holds the live slot.
  DwFlutterCore({
    required super.config,
    required DwWireProtocol protocol,
    required Uri baseUrl,
    super.plugins,
    DwTokenStore? tokenStore,
    DwHttpTransport? httpTransport,
    DwLiveConnector? liveConnector,
    DwClientOptions clientOptions = const DwClientOptions(),
  }) : _ownStore = _checkConfig(config, ownStore: tokenStore == null) {
    try {
      client = DwAppClient(
        protocol: protocol,
        baseUrl: baseUrl,
        appVersion: config.appVersion!,
        tokenStore:
            tokenStore ??
            DwKeyValueTokenStore(
              () => plugins.maybeOf<DwKeyValueStorePlugin>(),
            ),
        httpTransport: httpTransport,
        liveConnector: liveConnector,
        options: clientOptions,
        onError: (error, stackTrace) =>
            handleError(error, stackTrace, source: DwErrorSource.client),
      );
    } catch (_) {
      // The toolbox constructor has already claimed the live slot; a core
      // that failed to build must not keep it.
      detachDwInstance(this);
      rethrow;
    }
    // Every error report says who was signed in: the id is what an operator
    // looks the person up by.
    errorContext.register('account', () => client.accountId?.toString());
  }

  /// The client itself — for what the bindings do not cover, such as a
  /// one-off `fetch` outside any widget.
  late final DwAppClient client;

  final bool _ownStore;

  final Map<Object, Object> _providers = {};

  /// Initializes the plugins, then starts the client: reads the stored
  /// session. Does not wait for the server — a start offline is a start.
  @override
  Future<void> init() async {
    await super.init();
    if (_ownStore && plugins.maybeOf<DwKeyValueStorePlugin>() == null) {
      throw StateError(
        'DwFlutterCore keeps the session through the DwKeyValueStorePlugin '
        'role, and no plugin claims it. Declare one — plugins: '
        '[DwSharedPreferences()] — or pass tokenStore: explicitly.',
      );
    }
    await client.start();
  }

  /// Stops the client — closing every watch and the live socket — and
  /// releases the core.
  @override
  Future<void> dispose() async {
    await client.stop();
    _providers.clear();
    await super.dispose();
  }

  /// The live state of a single, maybe or list request, shared by every
  /// widget watching an equal request: `ref.watch(dw.request(request))`.
  ///
  /// A refusal, a failure, a signed-out answer and an unreachable server are
  /// errors of the `AsyncValue`, typed: [DwRefusalException],
  /// [DwFailedException], [DwNotAuthenticatedException],
  /// [DwTimeoutException]. Data being refreshed stays data.
  DwRequestProvider<R> request<R>(DwDataRequest<R> request) =>
      _provider<DwRequestProvider<R>>(
        ('request', request),
        (forget) =>
            NotifierProvider.autoDispose<DwRequestNotifier<R>, AsyncValue<R>>(
              () => DwRequestNotifier<R>(client, request, onDispose: forget),
              name: 'dw.request(${request.dwTypeName})',
            ),
      );

  /// The loaded pages of a feed: `ref.watch(dw.pages(request))`, and
  /// `ref.read(dw.pages(request).notifier).loadMore()` for the next page.
  DwPagesProvider<T> pages<T extends DwDataObject>(DwPageRequest<T> request) =>
      _provider<DwPagesProvider<T>>(
        ('pages', request),
        (forget) =>
            NotifierProvider.autoDispose<
              DwPagesNotifier<T>,
              AsyncValue<DwPagedData<T>>
            >(
              () => DwPagesNotifier<T>(client, request, onDispose: forget),
              name: 'dw.pages(${request.dwTypeName})',
            ),
      );

  /// One numbered page of a table: `ref.watch(dw.table(ListClients(page: 2)))`
  /// — rows, `total` and `pageCount`. Each page is its own request, so paging
  /// is watching another request.
  DwTableProvider<T> table<T extends DwDataObject>(DwTableRequest<T> request) =>
      _provider<DwTableProvider<T>>(
        ('table', request),
        (forget) =>
            NotifierProvider.autoDispose<
              DwTableNotifier<T>,
              AsyncValue<DwTablePage<T>>
            >(
              () => DwTableNotifier<T>(client, request, onDispose: forget),
              name: 'dw.table(${request.dwTypeName})',
            ),
      );

  /// A window over a newest-first sequence, opened around [anchor] or at the
  /// newest rows: `ref.watch(dw.window(request))`, and
  /// `ref.read(dw.window(request).notifier).loadOlder()` / `loadNewer()`.
  DwWindowProvider<T> window<T extends DwDataObject>(
    DwWindowRequest<T> request, {
    String? anchor,
  }) => _provider<DwWindowProvider<T>>(
    ('window', request, anchor),
    (forget) =>
        NotifierProvider.autoDispose<
          DwWindowNotifier<T>,
          AsyncValue<DwWindowData<T>>
        >(
          () => DwWindowNotifier<T>(
            client,
            request,
            anchor: anchor,
            onDispose: forget,
          ),
          name: 'dw.window(${request.dwTypeName})',
        ),
  );

  /// Runs [command], retried with the same idempotency key after network
  /// failures. Inside `dw.action`, a refused result is shown through
  /// [DwConfig.refusalText] without further code:
  /// `dw.action((context) => dw.command(BookSession(sessionId: 3)))`.
  Future<DwCallResult<R>> command<R>(DwActionCommand<R> command) =>
      client.command(command);

  /// The signed-in account id, `null` when signed out.
  late final DwValueProvider<int?> accountId =
      NotifierProvider<Notifier<int?>, int?>(
        () => DwStreamValueNotifier<int?>(
          () => client.accountId,
          () => client.accountIdStream,
        ),
        name: 'dw.accountId',
      );

  /// Where the live socket stands — for an "offline, not live" hint. Calls
  /// work whatever it says; data on screen stops following the server while
  /// it is not [DwConnectionStatus.connected] or
  /// [DwConnectionStatus.idle].
  late final DwValueProvider<DwConnectionStatus> liveStatus =
      NotifierProvider<Notifier<DwConnectionStatus>, DwConnectionStatus>(
        () => DwStreamValueNotifier<DwConnectionStatus>(
          () => client.connectionStatus,
          () => client.connectionStatusStream,
        ),
        name: 'dw.liveStatus',
      );

  /// Why this build can no longer talk to its server, or `null`. The
  /// bootstrapper shows [DwConfig.updateRequiredScreen] when it is set.
  late final DwValueProvider<DwCallRefusal?> incompatibility =
      NotifierProvider<Notifier<DwCallRefusal?>, DwCallRefusal?>(
        () => DwStreamValueNotifier<DwCallRefusal?>(
          () => client.incompatibility,
          () => client.incompatibilityStream,
        ),
        name: 'dw.incompatibility',
      );

  /// Adopts a session — the answer of `DwVerifyCode` — and keeps it across
  /// restarts. When the account changes, every watched request is released
  /// and asked again for the new account.
  Future<void> signIn(DwAuthSession session) => client.signIn(session);

  /// Signs out: the local session ends at once, every watched request is
  /// asked again anonymously, and the server revokes the key.
  Future<void> signOut() => client.signOut();

  /// One cached provider per [key], forgotten when its notifier is disposed —
  /// only that provider: an equal request may already have a newer one.
  P _provider<P extends Object>(
    Object key,
    P Function(void Function() forget) create,
  ) {
    final cached = _providers[key];
    if (cached is P) return cached;
    late final P provider;
    provider = create(() {
      if (identical(_providers[key], provider)) _providers.remove(key);
    });
    _providers[key] = provider;
    return provider;
  }

  /// Checked in the initializer list, so a core that cannot show refusals or
  /// name its build is refused before it claims the live slot.
  static bool _checkConfig(DwConfig config, {required bool ownStore}) {
    if (config.refusalText == null) {
      throw ArgumentError(
        'DwConfig.refusalText is required by DwFlutterCore: every refusal the '
        'server sends is a code, and the app is what turns it into words.',
      );
    }
    if (config.appVersion == null) {
      throw ArgumentError(
        'DwConfig.appVersion is required by DwFlutterCore: every call names '
        'the build (`1.4.2+57`), and the server refuses one it no longer '
        'supports.',
      );
    }
    return ownStore;
  }
}
