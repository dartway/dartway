import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/app/session/service/dw_auth_storage_interface.dart';
import 'package:dartway_serverpod_core_flutter/src/app/session/service/dw_authentification_key_manager.dart';
import 'package:dartway_serverpod_core_flutter/src/app/session/service/dw_session_service.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    DwCoreServerpodClient.protocol = _FakeProtocol();
    // Register the types DwSessionService subscribes to on init, so
    // DwRepository.typeName<T>() does not throw.
    DwRepository.setupRepository(defaultModel: _FakeProfile(0));
    DwRepository.setupRepository(
      defaultModel: DwAuthData(
        userProfile: _FakeProfile(0),
        userId: 0,
        key: 'k',
        keyId: 0,
      ),
    );
  });

  test('signs the user in with the profile the server confirms', () async {
    final fromServer = _FakeProfile(1);
    final keyManager = _FakeKeyManager((1, _FakeProfile(1)));
    final service = _buildService(
      keyManager: keyManager,
      fetchUserProfile: (_) async => fromServer,
    );

    await service.initialize();

    expect(service.currentUserProfile, same(fromServer));
    expect(service.currentUserId, 1);
    expect(keyManager.storedProfile, same(fromServer));
    expect(keyManager.removeCalls, 0);
  });

  test('drops the session when the server has no profile for it', () async {
    // Expired key, user deleted, or a fresh database: the server answers with
    // an empty value rather than an error, and the cached profile must not
    // survive it — this is the "still signed in as the previous user" bug.
    final keyManager = _FakeKeyManager((1, _FakeProfile(1)));
    final signedIn = <int?>[];
    final service = _buildService(
      keyManager: keyManager,
      fetchUserProfile: (_) async => null,
      onUserChanged: (_, id) => signedIn.add(id),
    );

    await service.initialize();

    expect(service.currentUserProfile, isNull);
    expect(service.currentUserId, isNull);
    expect(keyManager.removeCalls, 1);
    expect(signedIn, [null]);
  });

  test('drops a stored key that resolves to no user id', () async {
    final keyManager = _FakeKeyManager((null, null));
    var fetched = false;
    final service = _buildService(
      keyManager: keyManager,
      fetchUserProfile: (_) async {
        fetched = true;
        return null;
      },
    );

    await service.initialize();

    expect(fetched, isFalse);
    expect(service.currentUserId, isNull);
    expect(keyManager.removeCalls, 1);
  });

  test(
    'keeps the cached profile when validation fails on connection',
    () async {
      final cached = _FakeProfile(1);
      final keyManager = _FakeKeyManager((1, cached));
      final service = _buildService(
        keyManager: keyManager,
        fetchUserProfile: (_) async =>
            throw TimeoutException('Future not completed'),
      );

      await service.initialize(); // must NOT throw

      expect(service.currentUserProfile, same(cached));
      expect(service.currentUserId, 1);
      expect(keyManager.removeCalls, 0);
      await service.initialize(); // already initialized → no-op
    },
  );

  test('rethrows when there is no cached profile', () async {
    final service = _buildService(
      keyManager: _FakeKeyManager((1, null)),
      fetchUserProfile: (_) async =>
          throw TimeoutException('Future not completed'),
    );

    await expectLater(service.initialize(), throwsA(isA<TimeoutException>()));
  });

  test('rethrows a non-connection error even with a cached profile', () async {
    final service = _buildService(
      keyManager: _FakeKeyManager((1, _FakeProfile(1))),
      fetchUserProfile: (_) async => throw StateError('genuine bug'),
    );

    await expectLater(service.initialize(), throwsA(isA<StateError>()));
  });
}

DwSessionService<_FakeProfile> _buildService({
  required _FakeKeyManager keyManager,
  required Future<_FakeProfile?> Function(int userId) fetchUserProfile,
  DwSessionUserChangedListener<_FakeProfile>? onUserChanged,
}) {
  return DwSessionService<_FakeProfile>(
    keyManager: keyManager,
    onUserChanged: onUserChanged ?? (_, _) {},
    fetchUserProfile: fetchUserProfile,
    deleteAuthKey: (_) async {},
  );
}

class _FakeProfile implements SerializableModel {
  _FakeProfile(this.id);
  final int id;
  @override
  Map<String, dynamic> toJson() => {'id': id};
}

class _FakeProtocol extends SerializationManager {
  @override
  String? getClassNameForObject(Object? data) {
    if (data is _FakeProfile) return 'FakeProfile';
    if (data is DwAuthData) return 'DwAuthData';
    return super.getClassNameForObject(data);
  }
}

class _NoopStorage implements Storage {
  @override
  Future<int?> getInt(String key) async => null;
  @override
  Future<String?> getString(String key) async => null;
  @override
  Future<void> setInt(String key, int value) async {}
  @override
  Future<void> setString(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

class _FakeKeyManager extends DwAuthenticationKeyManager {
  _FakeKeyManager(this._result) : super(storage: _NoopStorage());
  final (int?, SerializableModel?) _result;

  int removeCalls = 0;
  SerializableModel? storedProfile;

  @override
  Future<(int?, T?)>
  loadLocalUserProfile<T extends SerializableModel>() async =>
      (_result.$1, _result.$2 as T?);

  @override
  Future<void> remove() async => removeCalls++;

  @override
  Future<void> storeUserProfile<T extends SerializableModel>(T profile) async =>
      storedProfile = profile;
}
