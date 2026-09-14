import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../dw_client_exceptions.dart';
import '../dw_client_options.dart';
import '../session/dw_token_store.dart';
import '../state/dw_request_state.dart';
import '../transport/dw_http_transport.dart';
import '../transport/dw_live_connection.dart';
import '../transport/dw_storage_transport.dart';
import '../transport/dw_web_socket_connector.dart';

part 'calls.dart';
part 'entries.dart';
part 'files.dart';
part 'live.dart';
part 'pages_entry.dart';
part 'replay.dart';
part 'update_rules.dart';
part 'value_entry.dart';
part 'watches.dart';
part 'window_entry.dart';

/// Where the live socket stands. The socket carries subscriptions and other
/// people's updates only — calls are HTTP and work whatever this says — so
/// the status is what an "offline, data may be stale" hint reads.
enum DwConnectionStatus {
  /// No socket, because nothing watched is live (no request declares a
  /// channel), nobody is signed in (every subscription requires an account),
  /// or the client is not started.
  idle,

  /// Opening the socket, or authenticating it.
  connecting,

  /// Open and authenticated: subscriptions are made as they are needed.
  connected,

  /// The socket is down and the client waits before the next attempt. Data
  /// on screen is not live meanwhile.
  disconnected,

  /// This build cannot talk to this server (`DwAppClient.incompatibility`).
  /// Terminal.
  incompatible,
}

enum _Lifecycle { created, started, stopped }

/// The state key of a watched request: whose it is, what it asks, and — for
/// a window — where it opened. Entries of another account are never looked
/// up, so switching accounts cannot show another account's data.
typedef _EntryKey = (
  int? account,
  DwDataRequest<Object?> request,
  String? anchor,
);

/// The client side of a DartWay app.
///
/// Calls go over HTTP — `POST <baseUrl>/dw/<WireName>` — and the answer's
/// updates are applied to every watched request before the call completes.
/// A WebSocket (`<baseUrl>/dw/live`) is opened only while something watched
/// declares channels and an account is signed in, and carries subscriptions
/// and other people's updates. Signed out, a request with channels is
/// fetched at once and is not live; it becomes live after sign-in.
///
/// ```dart
/// final client = DwAppClient(
///   protocol: appProtocol,
///   baseUrl: Uri.parse('https://api.example.com'),
///   appVersion: '1.4.2+57',
/// );
/// await client.start();
/// final watch = client.watch(const ListUpcomingSessions());
/// final result = await client.command(BookSession(sessionId: 3));
/// ```
///
/// State is scoped by account: every watched request lives under the account
/// that is signed in, and switching accounts releases all of it before the
/// next account's requests are asked. A client holds no static state: create
/// as many as a test needs and [stop] each. A stopped client is finished.
final class DwAppClient {
  /// Throws [FormatException] for an [appVersion] that is not
  /// `<semver>+<build>`, and [ArgumentError] for a [baseUrl] that is not an
  /// `http` or `https` URL without a query.
  DwAppClient({
    required this.protocol,
    required Uri baseUrl,
    required String appVersion,
    DwTokenStore? tokenStore,
    DwHttpTransport? httpTransport,
    DwLiveConnector? liveConnector,
    DwStorageTransport? storageTransport,
    this.options = const DwClientOptions(),
    void Function(Object error, StackTrace stackTrace)? onError,
    Random? random,
  }) : baseUrl = _checkBaseUrl(baseUrl),
       appVersion = DwAppVersion.parse(appVersion),
       tokenStore = tokenStore ?? DwMemoryTokenStore(),
       httpTransport = httpTransport ?? DwHttpClientTransport(),
       _ownsTransport = httpTransport == null,
       liveConnector = liveConnector ?? const DwWebSocketConnector(),
       storageTransport = storageTransport ?? DwHttpStorageTransport(),
       _ownsStorageTransport = storageTransport == null,
       _onError = onError,
       _random = random ?? Random.secure();

  /// The DTOs this client and its server agree on.
  final DwWireProtocol protocol;

  /// Where the server is: `https://api.example.com`, or a prefix under which
  /// it is proxied (`https://app.example.com/backend`). Call paths and the
  /// live path are appended to its path.
  final Uri baseUrl;

  /// This build, sent on every call and on the live upgrade; a build below
  /// the server's minimum answers `dw.updateRequired`.
  final DwAppVersion appVersion;

  final DwTokenStore tokenStore;
  final DwHttpTransport httpTransport;
  final DwLiveConnector liveConnector;

  /// Where upload bytes go: straight to storage, by presigned URLs.
  final DwStorageTransport storageTransport;

  final DwClientOptions options;

  final bool _ownsTransport;
  final bool _ownsStorageTransport;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final Random _random;

  static Uri _checkBaseUrl(Uri url) {
    if ((url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw ArgumentError.value(
        url,
        'baseUrl',
        'must be an http or https URL without a query or fragment',
      );
    }
    return url;
  }

  _Lifecycle _lifecycle = _Lifecycle.created;
  Future<void>? _starting;

  /// Completes once the stored session is known: nothing is asked of the
  /// server before, since the answer would be for an account that may not
  /// be the one signed in.
  final Completer<void> _sessionLoaded = Completer<void>();
  bool get _sessionReady =>
      _sessionLoaded.isCompleted && _lifecycle == _Lifecycle.started;

  // --- session --------------------------------------------------------------

  DwAuthSession? _session;

  /// Increments with every local session change, so a slow store read at
  /// start cannot overwrite a sign-in that happened meanwhile.
  int _sessionVersion = 0;

  final _account = _Replay<int?>(null);
  final _incompatibility = _Replay<DwCallRefusal?>(null);

  // --- state ----------------------------------------------------------------

  final Map<_EntryKey, _Entry> _entries = {};

  // --- live socket and retries (see live.dart, calls.dart) -------------------

  final _status = _Replay<DwConnectionStatus>(DwConnectionStatus.idle);
  final _LiveState _liveState = _LiveState();
  final Map<String, _ChannelRecord> _channels = {};

  /// Calls waiting out a backoff; woken early when the network is back.
  final Set<Completer<void>> _retryWaiters = {};

  /// Every open watch. A watch outlives the entry it shows: on an account
  /// switch it is moved to the next account's entry of its request.
  final Set<_Watch<Object?>> _watches = {};

  /// One-shot calls not yet answered, by the function that ends each with an
  /// error — how [stop] ends them.
  final Set<void Function(Object error)> _pendingCalls = {};

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Reads the stored session; completes once it is known, without waiting
  /// for the server. Watches and calls made before wait for it.
  Future<void> start() {
    _checkNotStopped();
    return _starting ??= _begin();
  }

  /// Ends the client: stops retrying and reconnecting, closes the live
  /// socket, ends every unanswered call with [DwClientStoppedException] and
  /// closes every watch. Nothing is sent to the server — it drops a closed
  /// socket's subscriptions itself.
  Future<void> stop() async {
    if (_lifecycle == _Lifecycle.stopped) return;
    _lifecycle = _Lifecycle.stopped;
    if (!_sessionLoaded.isCompleted) _sessionLoaded.complete();
    _stopLive();
    _wakeRetries();
    for (final abort in _pendingCalls.toList()) {
      abort(const DwClientStoppedException());
    }
    _pendingCalls.clear();
    for (final watch in _watches.toList()) {
      watch._closeFromClient();
    }
    _watches.clear();
    for (final entry in _entries.values.toList()) {
      entry.dispose();
    }
    _entries.clear();
    _channels.clear();
    final connection = _liveConnection;
    if (connection != null) await connection.close();
    if (_ownsTransport) httpTransport.close();
    if (_ownsStorageTransport) storageTransport.close();
    _status.close();
    _account.close();
    _incompatibility.close();
  }

  /// File uploads and links: `client.files.upload(...)`.
  late final DwFileClient files = DwFileClient._(this);

  /// The signed-in account id, or `null`. Known from the stored session right
  /// after [start], and corrected by the server: a rejected token makes it
  /// `null`.
  int? get accountId => _account.value;

  /// [accountId]: the current value first, then every change.
  Stream<int?> get accountIdStream => _account.stream;

  /// Where the live socket stands.
  DwConnectionStatus get connectionStatus => _status.value;

  /// [connectionStatus]: the current value first, then every change.
  Stream<DwConnectionStatus> get connectionStatusStream => _status.stream;

  /// Why this build cannot talk to its server — `dw.updateRequired` or
  /// `dw.protocolUnsupported` — or `null` while it can.
  ///
  /// Terminal once set: the live socket is closed and not reopened, every
  /// call answers [DwCallRefused] with this refusal without reaching the
  /// network, and every watched request shows it. An app puts a full-screen
  /// "update the app" page over everything.
  DwCallRefusal? get incompatibility => _incompatibility.value;

  /// [incompatibility]: the current value first, then the change.
  Stream<DwCallRefusal?> get incompatibilityStream => _incompatibility.stream;

  /// Adopts [session] — the answer of `DwVerifyCode` — and stores it.
  ///
  /// When it is another account than the one signed in, every watched request
  /// is released and asked again for the new account: nothing of the previous
  /// account stays on screen. Completes once the session is stored.
  Future<void> signIn(DwAuthSession session) async {
    _checkNotStopped();
    _setSession(session);
    await tokenStore.write(session);
  }

  /// Signs out: ends the local session at once — every watched request is
  /// released and asked again anonymously — and asks the server to revoke the
  /// key with `DwSignOut`, carrying the token that was signed in.
  ///
  /// Completes when the server has answered. A revocation that did not
  /// happen (refused, failed, unreachable within `callTimeout`) is reported
  /// to `onError` as [DwSignOutException]; the local session is over either
  /// way.
  Future<void> signOut() async {
    _checkNotStopped();
    // Only when not started: awaiting a completed start would still yield, and
    // the session must end in the caller's own turn.
    if (!_sessionReady) await start();
    final session = _session;
    if (session == null) return;
    _endSession();
    final Object outcome;
    try {
      outcome = await _oneShot<void>(
        const DwSignOut(),
        null,
        token: (session.token,),
      );
    } on DwClientStoppedException {
      return;
    } on Exception catch (error, stackTrace) {
      _report(DwSignOutException(error), stackTrace);
      return;
    }
    // Not authenticated: the server did not know the key either, so there is
    // nothing left to revoke.
    if (outcome is DwCallRefused || outcome is DwCallFailed) {
      _report(DwSignOutException(outcome), StackTrace.current);
    }
  }

  /// Runs [request] once. [page] selects the rows of a paginated request: a
  /// [DwOffsetQuery] for a [DwPageRequest], a [DwWindowQuery] for a
  /// [DwWindowRequest]; the other kinds take none (a table's page is a field
  /// of the request).
  ///
  /// Retried after network failures until `options.callTimeout`, then
  /// completes with [DwTimeoutException]. A request that does not validate
  /// answers its first refusal at once, and nothing is sent. Throws
  /// [ArgumentError] for a [page] the request kind does not take.
  Future<DwCallResult<R>> fetch<R>(
    DwDataRequest<R> request, {
    DwPageQuery? page,
  }) {
    final valid = switch (request) {
      DwPageRequest() => page == null || page is DwOffsetQuery,
      DwWindowRequest() => page == null || page is DwWindowQuery,
      _ => page == null,
    };
    if (!valid) {
      throw ArgumentError.value(
        page,
        'page',
        '${request.dwTypeName} does not take this page query',
      );
    }
    return _oneShot<R>(request, page);
  }

  /// Runs [command] once.
  ///
  /// The command carries an idempotency key generated for this call and kept
  /// across its retries, so a retry after a lost answer is answered with the
  /// stored outcome instead of running twice. Retried after network failures
  /// until `options.callTimeout`; an answer of any kind is never retried. A
  /// command that does not validate answers its first refusal at once, and
  /// nothing is sent.
  Future<DwCallResult<R>> command<R>(DwActionCommand<R> command) =>
      _oneShot<R>(command, null);

  /// Watches a single, maybe or list request: its state now and as it
  /// changes.
  ///
  /// All watches of equal requests share one entry — one fetch, one set of
  /// channel subscriptions (reference-counted across entries as well). The
  /// entry is released `options.releaseDelay` after its last watch closes.
  /// Throws [ArgumentError] for a paginated request, which has a method of
  /// its own.
  DwRequestWatch<R> watch<R>(DwDataRequest<R> request) {
    _checkNotStopped();
    final other = switch (request) {
      DwPageRequest() => 'watchPages',
      DwTableRequest() => 'watchTable',
      DwWindowRequest() => 'watchWindow',
      _ => null,
    };
    if (other != null) {
      throw ArgumentError.value(
        request,
        'request',
        '${request.dwTypeName} is paginated: watch it with $other',
      );
    }
    return _open(DwRequestWatch<R>._(this, request));
  }

  /// Watches one numbered page of a table: its rows and the total. Each page
  /// is its own request, so each is its own entry; rows on it are updated
  /// live, nothing is inserted, and a deletion reads the page again.
  DwRequestWatch<DwTablePage<T>> watchTable<T extends DwDataObject>(
    DwTableRequest<T> request,
  ) {
    _checkNotStopped();
    return _open(
      DwRequestWatch<DwTablePage<T>>._(
        this,
        request,
        (key) => _TableEntry<T>(this, key),
      ),
    );
  }

  /// Watches an accumulating feed: the first page now, the next on
  /// [DwPagesWatch.loadMore], updates merged live.
  DwPagesWatch<T> watchPages<T extends DwDataObject>(DwPageRequest<T> request) {
    _checkNotStopped();
    return _open(DwPagesWatch<T>._(this, request));
  }

  /// Watches a window over a newest-first sequence, opened around the row of
  /// [anchor] (a `DwWindowCursor` string the server produced) or at the
  /// newest rows; [DwWindowWatch.loadOlder] and [DwWindowWatch.loadNewer]
  /// grow it. Windows of one request opened at different anchors are
  /// different entries.
  DwWindowWatch<T> watchWindow<T extends DwDataObject>(
    DwWindowRequest<T, Object, Object> request, {
    String? anchor,
  }) {
    _checkNotStopped();
    return _open(DwWindowWatch<T>._(this, request, anchor));
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  void _checkNotStopped() {
    if (_lifecycle == _Lifecycle.stopped) {
      throw StateError('This DwAppClient is stopped. Create a new one.');
    }
  }

  Future<void> _begin() async {
    _lifecycle = _Lifecycle.started;
    final version = _sessionVersion;
    try {
      final stored = await tokenStore.read();
      if (version == _sessionVersion && stored != null) {
        _session = stored;
        _account.value = stored.id;
      }
    } catch (error, stackTrace) {
      // A store that cannot be read starts the app signed out; a person
      // signing in again is recoverable, a start that never finishes is not.
      _report(error, stackTrace);
    }
    if (_lifecycle != _Lifecycle.started) return;
    _sessionLoaded.complete();
    for (final watch in _watches.toList()) {
      _bind(watch);
    }
  }

  W _open<W extends _Watch<Object?>>(W watch) {
    _watches.add(watch);
    _bind(watch);
    return watch;
  }

  /// Puts [watch] on the entry of its request for the current account,
  /// creating the entry when there is none. Before the session is known a
  /// watch waits unbound, showing loading.
  void _bind(_Watch<Object?> watch) {
    if (!_sessionReady || watch._closed) return;
    final key = (_session?.id, watch._request, watch._anchor);
    var entry = _entries[key];
    if (entry == null) {
      final created = entry = watch._createEntry(key);
      _entries[key] = created;
      // Channels first: the live socket starts connecting before the entry
      // decides whether to wait for its subscriptions.
      _attachChannels(created);
      created.begin();
    }
    entry.retain(watch);
    watch._entry = entry;
    watch._notify();
  }

  void _release(_Entry entry) {
    if (entry.watches.isNotEmpty || entry.disposed) return;
    final delay = options.releaseDelay;
    if (delay == Duration.zero) {
      _disposeEntry(entry);
      return;
    }
    entry.releaseTimer = Timer(delay, () {
      if (entry.watches.isEmpty && !entry.disposed) _disposeEntry(entry);
    });
  }

  void _disposeEntry(_Entry entry) {
    if (identical(_entries[entry.key], entry)) _entries.remove(entry.key);
    entry.dispose();
    _detachChannels(entry);
  }

  // ===========================================================================
  // Session and account scope
  // ===========================================================================

  /// Makes [next] the session. When the account changes, every entry is
  /// released first — its subscriptions with it — then the live socket is
  /// authenticated as the next account, then the watches are put on the next
  /// account's entries. That order keeps a subscription checked for one
  /// account from ever feeding another account's state.
  void _setSession(DwAuthSession? next) {
    final previous = _session;
    _session = next;
    _sessionVersion++;
    _account.value = next?.id;
    final accountChanged = previous?.id != next?.id;
    if (accountChanged) {
      for (final watch in _watches) {
        watch._entry = null;
      }
      for (final entry in _entries.values.toList()) {
        _disposeEntry(entry);
      }
    }
    _authenticateLive(next?.token);
    if (accountChanged) {
      for (final watch in _watches.toList()) {
        _bind(watch);
      }
    }
    // Signing in or out changes whether the socket is wanted at all, even
    // when no entry was rebound to say so.
    _updateLiveDemand();
  }

  /// The session is over (a revoked or rejected token, a sign-out): forget it
  /// here and in the store.
  void _endSession() {
    if (_session == null) return;
    _setSession(null);
    unawaited(
      tokenStore.clear().catchError((Object error, StackTrace stackTrace) {
        _report(error, stackTrace);
      }),
    );
  }

  /// The server says [session]'s token belongs to [accountId]: it knows best.
  void _correctAccount(DwAuthSession session, int accountId) {
    final corrected = DwAuthSession(
      id: accountId,
      token: session.token,
      isNewAccount: false,
    );
    _setSession(corrected);
    unawaited(
      tokenStore.write(corrected).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _report(error, stackTrace);
      }),
    );
  }

  // ===========================================================================
  // Incompatibility
  // ===========================================================================

  /// This build cannot talk to this server: terminal. The socket closes and
  /// stays closed, sleeping retries wake to the refusal, and every entry
  /// settles on it.
  void _becomeIncompatible(DwCallRefusal refusal) {
    if (_incompatibility.value != null || _lifecycle == _Lifecycle.stopped) {
      return;
    }
    _incompatibility.value = refusal;
    _status.value = DwConnectionStatus.incompatible;
    _stopLive();
    final connection = _liveConnection;
    if (connection != null) unawaited(connection.close());
    _wakeRetries();
    for (final entry in _entries.values.toList()) {
      entry.onLiveChanged();
    }
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// The first refusal a call answers before reaching its handler, known
  /// without asking the server: a table page below 1, then `validate()`.
  DwCallRefusal? _localRefusal(DwServerCall<Object?> call) {
    if (call is DwTableRequest) {
      final refusal = call.checkPage();
      if (refusal != null) return refusal;
    }
    if (call case final DwSelfValidating validating) {
      final refusals = validating.validate();
      if (refusals.isNotEmpty) return refusals.first;
    }
    return null;
  }

  /// A delay after [failures] consecutive failures: doubling from
  /// `retryDelay` up to `maxRetryDelay`, drawn between half and the whole.
  Duration _backoff(int failures) {
    final max = options.maxRetryDelay.inMicroseconds;
    var micros = options.retryDelay.inMicroseconds;
    for (var i = 1; i < failures && micros < max; i++) {
      micros *= 2;
    }
    micros = min(micros, max);
    final half = micros ~/ 2;
    return Duration(microseconds: half + _random.nextInt(half + 1));
  }

  /// 128 random bits as 32 hex digits, drawn 16 bits at a time: shifts and
  /// values past 32 bits do not survive compilation to JavaScript.
  String _newIdempotencyKey() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'));
    }
    return buffer.toString();
  }

  /// The path of [suffix] under [baseUrl]'s path.
  String _pathOf(String suffix) {
    final base = baseUrl.path;
    return base.endsWith('/')
        ? '${base.substring(0, base.length - 1)}$suffix'
        : '$base$suffix';
  }

  void _report(Object error, StackTrace stackTrace) {
    final onError = _onError;
    if (onError != null) {
      onError(error, stackTrace);
    } else {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }
}
