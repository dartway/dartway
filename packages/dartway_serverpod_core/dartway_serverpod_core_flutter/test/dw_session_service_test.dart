import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/app/session/service/dw_auth_storage_interface.dart';
import 'package:dartway_serverpod_core_flutter/app/session/service/dw_authentification_key_manager.dart';
import 'package:dartway_serverpod_core_flutter/app/session/service/dw_session_service.dart';
import 'package:dartway_serverpod_core_flutter/repository/dw_repository.dart';
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

  test('keeps cached profile when refresh fails with a connection error', () async {
    final cached = _FakeProfile(1);
    final service = _buildService(
      cached: (1, cached),
      fetchUserProfile: (_) async =>
          throw TimeoutException('Future not completed'),
    );

    await service.initialize(); // must NOT throw

    expect(service.currentUserProfile, same(cached));
    expect(service.currentUserId, 1);
    await service.initialize(); // already initialized → no-op
  });

  test('rethrows when there is no cached profile', () async {
    final service = _buildService(
      cached: (1, null),
      fetchUserProfile: (_) async =>
          throw TimeoutException('Future not completed'),
    );

    await expectLater(service.initialize(), throwsA(isA<TimeoutException>()));
  });

  test('rethrows a non-connection error even with a cached profile', () async {
    final service = _buildService(
      cached: (1, _FakeProfile(1)),
      fetchUserProfile: (_) async => throw StateError('genuine bug'),
    );

    await expectLater(service.initialize(), throwsA(isA<StateError>()));
  });
}

DwSessionService<_FakeProfile> _buildService({
  required (int?, SerializableModel?) cached,
  required Future<void> Function(int userId) fetchUserProfile,
}) {
  return DwSessionService<_FakeProfile>(
    keyManager: _FakeKeyManager(cached),
    onUserChanged: (_, _) {},
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

  @override
  Future<(int?, T?)> loadLocalUserProfile<T extends SerializableModel>() async =>
      (_result.$1, _result.$2 as T?);
}
