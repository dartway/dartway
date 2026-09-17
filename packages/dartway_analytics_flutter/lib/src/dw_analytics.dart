import 'dart:async';
import 'dart:math';

import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'dw_analytics_store.dart';

/// Analytics for a DartWay app — `dw.plugins.analytics`.
///
/// ```dart
/// dw = DwFlutterCore(
///   ...,
///   protocol: DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol),
///   plugins: [DwAnalytics(attribution: readUtm)],
/// );
///
/// dw.plugins.analytics.track(ShopEvent.productViewed, {'productId': id});
/// ```
///
/// An event costs no call: it is numbered, kept on the device and sent with
/// others in one `DwTrackEvents` — every [flushInterval], when [batchSize]
/// events wait, and when the app goes to the background. Unsent events
/// survive a restart and a lost connection; the server keeps each number
/// once, so a batch sent twice is stored once.
///
/// By itself it records the app opening (with the [attribution] the project
/// reads), coming back, going to the background, and the signed-in account
/// changing (`DwAppEvent`). The install id is created once and kept: it ties
/// what a person did before signing in to the account they signed in as.
///
/// A batch is attributed by the server to the account the call is signed in
/// as. Events waiting at a sign-in are sent right away, so they go out under
/// the account that recorded them unless the send itself is outrun.
class DwAnalytics extends DwFlutterPlugin with WidgetsBindingObserver {
  DwAnalytics({
    this.attribution,
    this.lifecycleEvents = true,
    this.flushInterval = const Duration(seconds: 30),
    this.batchSize = 50,
    this.maxQueued = 1000,
    DwAnalyticsStore? store,
    this.platform,
  }) : store = store ?? DwPreferencesAnalyticsStore();

  /// Properties of the app opening: the campaign it came from (UTM on the
  /// web, a store referrer), read by the project.
  final Future<Map<String, Object?>> Function()? attribution;

  /// Whether the app's opening, resuming, backgrounding and account changes
  /// are recorded.
  final bool lifecycleEvents;

  final Duration flushInterval;

  /// Waiting events that trigger a send before [flushInterval].
  final int batchSize;

  /// Events kept while the server cannot be reached; beyond it the oldest go.
  final int maxQueued;

  final DwAnalyticsStore store;

  /// The platform sent with batches; by default this build's.
  final DwAnalyticsPlatform? platform;

  @override
  bool get blocksStartup => false;

  late final DwFlutterCore _core;
  late final String _installId;
  int _nextSequence = 1;
  final List<DwTrackedEvent> _queue = [];
  Timer? _timer;
  StreamSubscription<int?>? _accounts;
  bool _sending = false;
  bool _initialized = false;
  Future<void> _persisting = Future.value();

  /// This installation's id.
  String get installId => _installId;

  /// Events recorded and not yet confirmed by the server.
  List<DwTrackedEvent> get pending => List.unmodifiable(_queue);

  @override
  Future<void> init(DwFlutterToolbox core) async {
    if (core is! DwFlutterCore) {
      throw StateError(
        'DwAnalytics sends through the data layer: declare it on a '
        'DwFlutterCore, not a plain DwFlutterToolbox.',
      );
    }
    _core = core;
    if (!core.client.protocol.knows(DwTrackEvents)) {
      throw StateError(
        'The app protocol does not register DwTrackEvents: build it as '
        'DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol).',
      );
    }
    _installId = await store.readInstallId() ?? await _newInstallId();
    _nextSequence = await store.readNextSequence();
    for (final json in await store.readQueue()) {
      try {
        _queue.add(DwTrackedEvent.fromJson(json));
      } on Object {
        // A stored event this build cannot read is dropped, not retried.
      }
    }
    _initialized = true;

    if (lifecycleEvents) {
      var opened = const <String, Object?>{};
      try {
        opened = await attribution?.call() ?? const {};
      } catch (error, stackTrace) {
        core.handleError(error, stackTrace, source: DwErrorSource.client);
      }
      track(DwAppEvent.appOpened, opened);
      WidgetsBinding.instance.addObserver(this);
      int? previous = core.client.accountId;
      _accounts = core.client.accountIdStream.listen((accountId) {
        if (accountId == previous) return;
        previous = accountId;
        // What waited was recorded under the previous account: send it now.
        unawaited(flush());
        track(DwAppEvent.accountChanged, {'signedIn': accountId != null});
      });
    }
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
    unawaited(flush());
  }

  /// Records [event] with [properties]. Properties the store does not take
  /// are reported as an error and the event is dropped — a tracking call
  /// never breaks the screen that makes it.
  void track(
    DwAnalyticsEvent event, [
    Map<String, Object?> properties = const {},
  ]) {
    if (!_initialized) {
      _core.handleError(
        StateError('dw.plugins.analytics.track before dw.init()'),
        StackTrace.current,
        source: DwErrorSource.client,
      );
      return;
    }
    final recorded = DwTrackedEvent(
      name: event.eventName,
      occurredAt: DateTime.now().toUtc(),
      sequence: _nextSequence++,
      properties: Map.unmodifiable(properties),
    );
    if (recorded.problem case final problem?) {
      _core.handleError(
        ArgumentError(problem),
        StackTrace.current,
        source: DwErrorSource.client,
      );
      return;
    }
    _queue.add(recorded);
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    _persist();
    if (_queue.length >= batchSize) unawaited(flush());
  }

  /// Sends what waits, in batches, until nothing does or a send fails.
  Future<void> flush() async {
    if (!_initialized || _sending) return;
    _sending = true;
    try {
      while (_queue.isNotEmpty) {
        final events = _queue.take(DwTrackEvents.maxEvents).toList();
        final result = await _core.client.command(
          DwTrackEvents(
            installId: _installId,
            platform: platform ?? _currentPlatform(),
            appVersion: '${_core.client.appVersion}',
            events: events,
          ),
        );
        switch (result) {
          case DwCallOk():
            _remove(events);
          case DwCallRefused(:final refusal):
            // A batch the server will never take is not retried forever.
            _remove(events);
            _core.handleError(
              StateError('Analytics events were refused: ${refusal.code}'),
              StackTrace.current,
              source: DwErrorSource.client,
            );
          case DwNotAuthenticated() || DwCallFailed():
            return;
        }
      }
    } catch (_) {
      // Offline past the call deadline: the next flush tries again.
    } finally {
      _sending = false;
    }
  }

  void _remove(List<DwTrackedEvent> sent) {
    final numbers = {for (final event in sent) event.sequence};
    _queue.removeWhere((event) => numbers.contains(event.sequence));
    _persist();
  }

  void _persist() {
    final queue = [for (final event in _queue) event.toJson()];
    final next = _nextSequence;
    _persisting = _persisting.then((_) async {
      await store.writeNextSequence(next);
      await store.writeQueue(queue);
    });
  }

  /// Completes when everything recorded so far is written to the store.
  @visibleForTesting
  Future<void> get persisted => _persisting;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        track(DwAppEvent.appResumed);
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        track(DwAppEvent.appBackgrounded);
        unawaited(flush());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _accounts?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _persisting;
  }

  Future<String> _newInstallId() async {
    final random = Random.secure();
    final id = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    await store.writeInstallId(id);
    return id;
  }

  static DwAnalyticsPlatform _currentPlatform() {
    if (kIsWeb) return DwAnalyticsPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => DwAnalyticsPlatform.android,
      TargetPlatform.iOS => DwAnalyticsPlatform.ios,
      TargetPlatform.macOS => DwAnalyticsPlatform.macos,
      TargetPlatform.windows => DwAnalyticsPlatform.windows,
      TargetPlatform.linux => DwAnalyticsPlatform.linux,
      _ => DwAnalyticsPlatform.other,
    };
  }
}

/// `dw.plugins.analytics`.
extension DwAnalyticsAccess on DwPluginRegistry {
  DwAnalytics get analytics => of<DwAnalytics>();
}
