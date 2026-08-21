import 'dart:async';

import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Studio, as far as the app can tell. Everything Studio says crosses the wire
/// encoded, exactly as the real channel would.
class _FakeStudio implements StudioMessageChannel {
  final _incoming = StreamController<StudioBridgeMessage>.broadcast();
  final heard = <StudioBridgeMessage>[];

  @override
  Stream<StudioBridgeMessage> get messages => _incoming.stream;

  @override
  void send(StudioBridgeMessage message) => heard.add(message);

  @override
  void dispose() => _incoming.close();

  void say(StudioBridgeMessage message) {
    final decoded = StudioBridgeMessage.tryDecode(message.encode());
    expect(decoded, isNotNull);
    _incoming.add(decoded!);
  }

  Iterable<T> of<T extends StudioBridgeMessage>() => heard.whereType<T>();
}

/// A profile of this test's own invention — the binding never looks inside one,
/// it only hands it to `describeUser`.
class _Profile implements SerializableModel {
  _Profile(this.phone);

  final String phone;

  @override
  Map<String, dynamic> toJson() => {'phone': phone};
}

class _RouterState extends ChangeNotifier {}

class _Plain extends StatelessWidget {
  const _Plain();

  @override
  Widget build(BuildContext context) => const Text('plain');
}

/// A screen that declares a feature, so a scan over it finds something.
class _WithFeature extends StatelessWidget implements DwFeature {
  const _WithFeature();

  @override
  DwFeatureSpec get dwFeature =>
      const DwFeatureSpec(id: 'schedule.week', title: 'Week schedule');

  @override
  Widget build(BuildContext context) => const Text('schedule');
}

enum _Routes implements DwNavigationRoute<_RouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: _Plain())),
  schedule(
    DwNavigationRouteDescriptor.simple(
      pageWidget: _WithFeature(),
      parent: home,
    ),
  ),
  empty(DwNavigationRouteDescriptor.simple(pageWidget: _Plain(), parent: home));

  const _Routes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<_RouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<_RouterState>> get zoneGuards => [];
}

const _manifest = StudioProjectManifest(projectName: 'Binding test', zones: []);

late final DwCore<ServerpodClientShared, _Profile> _core;

void main() {
  setUpAll(() {
    // The core exists so the binding can name `userProfileProvider` and run the
    // persona flow; no test here reaches the server. One per process — DwCore
    // claims the ambient `dw`.
    _core = DwCore<ServerpodClientShared, _Profile>(
      config: const DwConfig(),
      transport: DwRecordingServerTransport(classNames: {_Profile: '_Profile'}),
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
    );
  });

  late _FakeStudio studio;
  late DwRouter<_RouterState> router;

  /// The binding schedules its re-scans on real delays, so a test that ends
  /// while one is outstanding fails on a pending timer rather than on its own
  /// assertion. One pump past the last delay closes the window.
  Future<void> drainRescanWindow(WidgetTester tester) async =>
      tester.pump(const Duration(milliseconds: 1200));

  Future<void> mountBinding(WidgetTester tester) async {
    studio = _FakeStudio();
    router = DwRouter<_RouterState>(
      navigationZones: [_Routes.values],
      pageBuilder: DwPageBuilder.material,
      routerState: _RouterState(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router.router,
          builder: (context, child) => DwStudioBinding<_Profile>(
            core: _core,
            manifest: _manifest,
            router: router,
            describeUser: (profile) => DwStudioUser(identifier: profile.phone),
            channel: studio,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    // Studio connects; without an accepted handshake the host reports nothing.
    studio.say(const StudioConnectMessage(accessToken: 'any'));
    await tester.pump();
    // Mounting settles a route of its own, which opens a re-scan window. Let it
    // close before a test starts measuring, or its reports arrive mid-assertion.
    await drainRescanWindow(tester);
  }

  testWidgets('an empty early re-scan is not reported as an empty screen', (
    tester,
  ) async {
    await mountBinding(tester);
    studio.heard.clear();

    // A screen with no features at all: every re-scan finds nothing, so the
    // early ones must stay silent and only the last may speak.
    router.router.go(_Routes.empty.fullPath);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 60));
    expect(
      studio.of<FeaturesChangedMessage>(),
      isEmpty,
      reason: 'the 50ms re-scan reported emptiness',
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(
      studio.of<FeaturesChangedMessage>(),
      isEmpty,
      reason: 'the 400ms re-scan reported emptiness',
    );

    await tester.pump(const Duration(milliseconds: 700));
    // The last one is allowed to: there the emptiness is real, not a screen
    // caught mid-swap.
    expect(studio.of<FeaturesChangedMessage>(), hasLength(1));
    expect(studio.of<FeaturesChangedMessage>().single.features, isEmpty);

    await drainRescanWindow(tester);
  });

  testWidgets('a screen that has features reports them', (tester) async {
    await mountBinding(tester);
    studio.heard.clear();

    router.router.go(_Routes.schedule.fullPath);
    // Let the page transition finish first. That it has to is the point of the
    // re-scan window in the first place: the screen a route change names is not
    // on screen at the moment the route changes.
    await tester.pumpAndSettle();
    await drainRescanWindow(tester);

    final reported = studio.of<FeaturesChangedMessage>();
    expect(reported, isNotEmpty);
    expect(reported.last.features.map((f) => f.id), ['schedule.week']);
    expect(reported.last.path, _Routes.schedule.fullPath);

    await drainRescanWindow(tester);
  });

  testWidgets('a route change is reported by name, not only by path', (
    tester,
  ) async {
    await mountBinding(tester);
    studio.heard.clear();

    router.router.go(_Routes.schedule.fullPath);
    await tester.pump();

    final route = studio.of<RouteChangedMessage>().last;
    expect(route.path, _Routes.schedule.fullPath);
    // The declared name is the identity a passport binds to — it survives a
    // path refactor, which is the whole reason it travels beside the path.
    expect(route.routeName, _Routes.schedule.name);

    await drainRescanWindow(tester);
  });

  testWidgets('a signed-out app describes its session as such', (tester) async {
    await mountBinding(tester);

    final session = studio.of<SessionChangedMessage>();
    expect(
      session.isEmpty || session.last.session.isSignedIn == false,
      isTrue,
      reason: 'nobody is signed in, so nothing may claim otherwise',
    );

    await drainRescanWindow(tester);
  });
}
