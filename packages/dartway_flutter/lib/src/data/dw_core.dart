import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dw_flutter.dart';
import '../core/logic/dw_config.dart';
import '../core/logic/dw_key_value_store.dart';
import '../diagnostics/error_reporting/logic/dw_error_source.dart';
import 'dw_key_value_token_store.dart';
import 'dw_request_notifiers.dart';

/// The app core with the data layer: the toolbox of [DwFlutter] plus one
/// [DwClient] and the Riverpod bindings over it.
///
/// ```dart
/// late final DwCore dw;
///
/// dw = DwCore(
///   config: DwConfig(refusalText: (refusal) => t.refusal(refusal)),
///   protocol: appProtocol,
///   endpoint: Uri.parse('wss://api.example.com/dw'),
///   plugins: [DwSharedPreferences()],
/// );
/// DwAppRunner(appInitializers: [dw.init], child: const App()).run();
///
/// ref.watch(dw.request(const ListUpcomingSessions()));  // AsyncValue<List<SessionView>>
/// ref.watch(dw.pages(const FeedPosts()));               // AsyncValue<DwPagedData<PostView>>
/// await dw.command(BookSession(sessionId: 3));          // DwResult<BookingView>
/// ref.watch(dw.accountId);                              // int?
/// ```
///
/// Two phases: the constructor builds and connects nothing; [init] starts the
/// plugins, then the client. [dispose] stops the client and releases the core,
/// after which another can be built — nothing here is static.
class DwCore extends DwFlutter {
  DwCore({
    required super.config,
    required DwProtocol protocol,
    required Uri endpoint,
    super.plugins,
    DwTokenStore? tokenStore,
    DwConnector? connector,
    DwClientOptions clientOptions = const DwClientOptions(),
  }) : _ownStore = _requireRefusalText(config, tokenStore == null) {
    client = DwClient(
      protocol: protocol,
      endpoint: endpoint,
      tokenStore:
          tokenStore ??
          DwKeyValueTokenStore(() => plugins.maybeOf<DwKeyValueStorePlugin>()),
      connector: connector,
      options: clientOptions,
      onError: (error, stackTrace) =>
          handleError(error, stackTrace, source: DwErrorSource.client),
    );
    // Every error report says who was signed in (DESIGN §6): the id is what
    // an operator looks the person up by.
    errorContext.register('account', () => client.accountId?.toString());
  }

  /// The client itself — for what the bindings do not cover, such as a
  /// one-off `fetch` outside any widget.
  late final DwClient client;

  final bool _ownStore;

  final Map<DwRequest<Object?>, Object> _requestProviders = {};
  final Map<DwRequest<Object?>, Object> _pagesProviders = {};

  /// Initializes the plugins, then starts the client: reads the stored session
  /// and begins connecting. Does not wait for the server — a start offline is
  /// a start.
  @override
  Future<void> init() async {
    await super.init();
    if (_ownStore && plugins.maybeOf<DwKeyValueStorePlugin>() == null) {
      throw StateError(
        'DwCore keeps the session through the DwKeyValueStorePlugin role, and '
        'no plugin claims it. Declare one — plugins: [DwSharedPreferences()] — '
        'or pass tokenStore: explicitly.',
      );
    }
    await client.start();
  }

  /// Stops the client — closing every watch and the connection — and releases
  /// the core.
  @override
  Future<void> dispose() async {
    await client.stop();
    _requestProviders.clear();
    _pagesProviders.clear();
    await super.dispose();
  }

  /// The live state of [request], shared by every widget watching an equal
  /// request: `ref.watch(dw.request(request))`.
  ///
  /// A refusal, a failure and a signed-out answer are errors of the
  /// `AsyncValue`, typed: [DwRefusalException], [DwFailedException],
  /// [DwNotAuthenticatedException]. Data being refreshed stays data.
  DwRequestProvider<R> request<R>(DwRequest<R> request) {
    final cached = _requestProviders[request];
    if (cached is DwRequestProvider<R>) return cached;
    late final DwRequestProvider<R> provider;
    provider =
        NotifierProvider.autoDispose<DwRequestNotifier<R>, AsyncValue<R>>(
          () => DwRequestNotifier<R>(
            client,
            request,
            onDispose: () => _forget(_requestProviders, request, provider),
          ),
          name: 'dw.request(${request.dwTypeName})',
        );
    _requestProviders[request] = provider;
    return provider;
  }

  /// The loaded pages of a paginated request:
  /// `ref.watch(dw.pages(request))`, and
  /// `ref.read(dw.pages(request).notifier).loadMore()` for the next page.
  DwPagesProvider<T> pages<T extends DwDataObject>(
    DwRequest<DwPage<T>> request,
  ) {
    final cached = _pagesProviders[request];
    if (cached is DwPagesProvider<T>) return cached;
    late final DwPagesProvider<T> provider;
    provider =
        NotifierProvider.autoDispose<
          DwPagesNotifier<T>,
          AsyncValue<DwPagedData<T>>
        >(
          () => DwPagesNotifier<T>(
            client,
            request,
            onDispose: () => _forget(_pagesProviders, request, provider),
          ),
          name: 'dw.pages(${request.dwTypeName})',
        );
    _pagesProviders[request] = provider;
    return provider;
  }

  /// Runs [command]; queued while offline, re-sent with the same idempotency
  /// key after a reconnect. Inside `dw.action`, a refused result is shown
  /// through [DwConfig.refusalText] without further code:
  /// `dw.action((context) => dw.command(BookSession(sessionId: 3)))`.
  Future<DwResult<R>> command<R>(DwCommand<R> command) =>
      client.command(command);

  /// The signed-in account id, `null` when signed out.
  late final DwValueProvider<int?> accountId =
      NotifierProvider<Notifier<int?>, int?>(
        () => DwStreamValueNotifier<int?>(
          () => client.accountId,
          () => client.session,
        ),
        name: 'dw.accountId',
      );

  /// The connection status — for an offline banner: data on screen is not
  /// live while this is not [DwConnectionStatus.connected].
  late final DwValueProvider<DwConnectionStatus> connectionStatus =
      NotifierProvider<Notifier<DwConnectionStatus>, DwConnectionStatus>(
        () => DwStreamValueNotifier<DwConnectionStatus>(
          () => client.connectionStatus,
          () => client.connectionStatuses,
        ),
        name: 'dw.connectionStatus',
      );

  /// Adopts a session — the answer of `DwVerifyCode` — and keeps it across
  /// restarts. Every watched request runs again as the new account.
  Future<void> signIn(DwSession session) => client.signIn(session);

  /// Signs out: the server revokes the key, the stored session is cleared,
  /// and every watched request runs again anonymously.
  Future<void> signOut() => client.signOut();

  /// Checked in the initializer list, so a core that cannot show refusals is
  /// refused before it claims the live slot: a data layer whose "no" reaches
  /// the user as nothing is not one to start.
  static bool _requireRefusalText(DwConfig config, bool ownStore) {
    if (config.refusalText == null) {
      throw ArgumentError(
        'DwConfig.refusalText is required by DwCore: every refusal the server '
        'sends is a code, and the app is what turns it into words.',
      );
    }
    return ownStore;
  }

  static void _forget(
    Map<DwRequest<Object?>, Object> providers,
    DwRequest<Object?> request,
    Object provider,
  ) {
    // Only this provider: an equal request may already have a newer one.
    if (identical(providers[request], provider)) providers.remove(request);
  }
}
