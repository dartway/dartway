import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwPush transport selection', () {
    test('takes the first declared transport that fits this device', () async {
      final ruStore = _FakeProvider(id: DwPushProviderIds.ruStore);
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(providers: [ruStore, firebase]);

      await push.attach();

      expect(push.provider?.id, DwPushProviderIds.ruStore);
      expect(firebase.attached, isFalse);
    });

    test('steps over a transport this platform does not build', () async {
      final ruStore = _FakeProvider(
        id: DwPushProviderIds.ruStore,
        isSupportedPlatform: false,
      );
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(providers: [ruStore, firebase]);

      await push.attach();

      expect(push.provider?.id, DwPushProviderIds.fcm);
      expect(ruStore.attached, isFalse);
    });

    test('steps over a transport missing on this device', () async {
      // RuStore builds fine on any Android, and then answers "not installed"
      // on a phone without the store app.
      final ruStore = _FakeProvider(
        id: DwPushProviderIds.ruStore,
        isAvailable: false,
      );
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(providers: [ruStore, firebase]);

      await push.attach();

      expect(push.provider?.id, DwPushProviderIds.fcm);
    });

    test('touches nothing when push is disabled for this build', () async {
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(
        providers: [firebase],
        isEnabled: () async => false,
      );

      await push.attach();

      expect(push.provider, isNull);
      expect(firebase.attached, isFalse);
      expect(firebase.permissionRequests, 0);
    });
  });

  group('DwPush permission', () {
    test('asks on attach by default', () async {
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      await _push(providers: [firebase]).attach();

      expect(firebase.permissionRequests, 1);
      expect(firebase.tokenRequests, 1);
    });

    test('stays quiet when the app asks at its own moment', () async {
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(
        providers: [firebase],
        requestPermissionOnAttach: false,
      );

      await push.attach();
      expect(firebase.permissionRequests, 0);

      await push.requestPermission();
      expect(firebase.permissionRequests, 1);
    });

    test('keeps listening after a refusal, so a later yes still works',
        () async {
      final firebase = _FakeProvider(
        id: DwPushProviderIds.fcm,
        permission: DwPushPermission.denied,
      );
      final push = _push(providers: [firebase]);

      await push.attach();

      expect(firebase.attached, isTrue);
      expect(push.token.value, isNull);

      firebase.permission = DwPushPermission.granted;
      await push.requestPermission();

      expect(push.token.value, 'token-fcm');
    });
  });

  group('DwPush notification taps', () {
    test('holds the notification that started the app until it can be routed',
        () async {
      final opened = <DwPushOpened>[];
      final firebase = _FakeProvider(
        id: DwPushProviderIds.fcm,
        initialPayload: {'type': 'new_post', 'post_id': '12'},
      );
      final push = _push(providers: [firebase], onOpened: opened.add);

      await push.attach();
      expect(opened, isEmpty, reason: 'nothing can route it yet');

      push.markReadyForOpens((action) => action());

      expect(opened, hasLength(1));
      expect(opened.single.source, DwPushOpenSource.coldStart);
      expect(opened.single.data['post_id'], '12');
    });

    test('delivers a buffered tap exactly once', () async {
      final opened = <DwPushOpened>[];
      final firebase = _FakeProvider(
        id: DwPushProviderIds.fcm,
        initialPayload: {'type': 'new_post'},
      );
      final push = _push(providers: [firebase], onOpened: opened.add);

      await push.attach();
      push.markReadyForOpens((action) => action());
      push.markReadyForOpens((action) => action());

      expect(opened, hasLength(1));
    });

    test('passes a web service worker path through as the link', () async {
      final opened = <DwPushOpened>[];
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(providers: [firebase], onOpened: opened.add);

      await push.attach();
      push.markReadyForOpens((action) => action());
      firebase.emitOpened({
        dwPushLinkDataKey: '/chats/12',
      }, DwPushOpenSource.webLink);

      expect(opened.single.link, '/chats/12');
    });
  });

  group('DwPush token registration', () {
    testWidgets('registers once the session says who is signed in',
        (tester) async {
      final registrations = <(String, String)>[];
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(
        providers: [firebase],
        recipientIdProvider: _signedInUserIdProvider,
        registerToken: ({required token, required provider}) async {
          registrations.add((token, provider));
          return true;
        },
      );
      await push.init(_core());

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: DwPushScope(push: push, child: const SizedBox()),
        ),
      );
      await tester.pump();

      expect(registrations, isEmpty, reason: 'nobody is signed in yet');

      container.read(_signedInUserIdProvider.notifier).signIn(42);
      await tester.pump();
      await tester.pump();

      expect(registrations, [('token-fcm', DwPushProviderIds.fcm)]);

      // The scope hands the recipient over on every build; a rebuild for some
      // unrelated reason must not become a second registration.
      tester.element(find.byType(DwPushScope)).markNeedsBuild();
      await tester.pump();
      await tester.pump();

      expect(registrations, hasLength(1));
    });

    test('has nobody to follow on a core without the data layer', () async {
      // `dw.signedInUserIdProvider` arrives with DwCore; the plain toolbox has
      // no session of any kind. Rather than guess, the plugin stays in manual
      // mode — the app supplies a provider or no token is ever registered.
      final push = _push(providers: [_FakeProvider(id: DwPushProviderIds.fcm)]);

      await push.init(_core());

      expect(push.recipientIdProvider, isNull);
    });
  });
}

/// Stands in for the app's session — the provider `DwPush` resolves out of the
/// core, driven here by hand so the whole path from a changed value to a
/// registration runs for real.
class _SignedInUserId extends Notifier<int?> {
  @override
  int? build() => null;

  void signIn(int? userId) => state = userId;
}

final _signedInUserIdProvider = NotifierProvider<_SignedInUserId, int?>(
  _SignedInUserId.new,
);

/// One core for the whole file: `DwFlutter`'s constructor claims the process-wide
/// `dw` singleton and throws on a second instance.
DwFlutter _core() => _instance ??= DwFlutter(config: const DwConfig());
DwFlutter? _instance;

DwPush _push({
  required List<DwPushClientProvider> providers,
  void Function(DwPushOpened opened)? onOpened,
  Future<bool> Function()? isEnabled,
  bool requestPermissionOnAttach = true,
  ProviderListenable<int?>? recipientIdProvider,
  Future<bool> Function({required String token, required String provider})?
  registerToken,
}) => DwPush(
  config: DwPushConfig(
    providers: providers,
    onOpened: onOpened,
    isEnabled: isEnabled,
    requestPermissionOnAttach: requestPermissionOnAttach,
    recipientIdProvider: recipientIdProvider,
    registerToken:
        registerToken ?? ({required token, required provider}) async => true,
  ),
);

class _FakeProvider extends DwPushClientProvider {
  _FakeProvider({
    required this.id,
    this.isSupportedPlatform = true,
    bool isAvailable = true,
    this.permission = DwPushPermission.granted,
    this.initialPayload,
  }) : _isAvailable = isAvailable;

  @override
  final String id;

  @override
  final bool isSupportedPlatform;

  final bool _isAvailable;
  final Map<String, String>? initialPayload;

  DwPushPermission permission;
  bool attached = false;
  int permissionRequests = 0;
  int tokenRequests = 0;
  DwPushProviderCallbacks? _callbacks;

  @override
  Future<bool> isAvailable() async => _isAvailable;

  @override
  Future<DwPushPermission> currentPermission() async => permission;

  @override
  Future<DwPushPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> attach(DwPushProviderCallbacks callbacks) async {
    attached = true;
    _callbacks = callbacks;
  }

  @override
  Future<void> detach() async {
    attached = false;
    _callbacks = null;
  }

  @override
  Future<String?> requestToken() async {
    tokenRequests++;
    return permission == DwPushPermission.granted ? 'token-$id' : null;
  }

  @override
  Future<Map<String, String>?> takeInitialPayload() async => initialPayload;

  void emitOpened(Map<String, String> data, DwPushOpenSource source) =>
      _callbacks?.onOpened(data, source);
}
