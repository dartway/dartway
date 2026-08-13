import 'package:dartway_push_flutter/dartway_push_flutter.dart';
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
    test('registers once the app says who is signed in', () async {
      final registrations = <(String, String)>[];
      final firebase = _FakeProvider(id: DwPushProviderIds.fcm);
      final push = _push(
        providers: [firebase],
        registerToken: ({required token, required provider}) async {
          registrations.add((token, provider));
          return true;
        },
      );

      await push.attach();
      expect(registrations, isEmpty, reason: 'nobody is signed in yet');

      push.setRecipient(42);
      await Future<void>.delayed(Duration.zero);

      expect(registrations, [('token-fcm', DwPushProviderIds.fcm)]);
    });
  });
}

DwPush _push({
  required List<DwPushClientProvider> providers,
  void Function(DwPushOpened opened)? onOpened,
  Future<bool> Function()? isEnabled,
  bool requestPermissionOnAttach = true,
  Future<bool> Function({required String token, required String provider})?
  registerToken,
}) => DwPush(
  config: DwPushConfig(
    providers: providers,
    onOpened: onOpened,
    isEnabled: isEnabled,
    requestPermissionOnAttach: requestPermissionOnAttach,
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
