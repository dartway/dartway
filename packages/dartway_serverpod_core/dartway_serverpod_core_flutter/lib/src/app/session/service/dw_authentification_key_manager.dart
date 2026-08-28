// This file includes code derived from the Serverpod project (https://github.com/serverpod/serverpod).
// Copyright (c) 2020 Serverpod. All rights reserved.
// Modified by Evgenii Novikov for DartWay.dev under the Apache License 2.0.

import 'dart:convert';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';

import '../../../private/dw_singleton.dart';

const _authKeyPrefsKey = 'dartway_authentication_key';
const _userProfilePrefsKey = 'dw_user_profile_key';
const _prefsVersion = 1;

/// Persistent auth key provider for DartWay Flutter clients.
class DwAuthenticationKeyManager implements ClientAuthKeyProvider {
  bool _initialized = false;
  String? _authenticationKey;

  /// The run mode of the Serverpod.
  final String runMode;

  final DwKeyValueStorePlugin? _injectedStore;
  DwKeyValueStorePlugin? _resolvedStore;

  /// Creates a new authentication key manager.
  ///
  /// Where the key is kept is a plugin's job. Passing [store] names one
  /// directly — a test double, or an app that keeps its key somewhere of its
  /// own; leaving it out asks the plugins for whoever claimed the
  /// [DwKeyValueStorePlugin] role.
  ///
  /// It used to reach for `shared_preferences` here, in the core's own copy of
  /// the contract, while `dartway_shared_preferences` implemented the same
  /// thing a package away. Two implementations of one job, agreeing only
  /// because they happened to sit on the same store — so a decision taken on
  /// one side could not be seen from the other, and a browser without local
  /// storage broke both, separately.
  DwAuthenticationKeyManager({
    this.runMode = 'production',
    DwKeyValueStorePlugin? store,
  }) : _injectedStore = store;

  /// Resolved on first use, not in the constructor: the key manager is built
  /// while the client is, which is before `dw.init()` has run the plugins.
  DwKeyValueStorePlugin get _storage {
    final store =
        _injectedStore ??
        (_resolvedStore ??= dw.plugins.maybeOf<DwKeyValueStorePlugin>());
    if (store == null) {
      throw StateError(
        'No DwKeyValueStorePlugin is declared, so there is nowhere to keep the '
        'authentication key and a signed-in session cannot survive a reload. '
        'Declare one at startup — DwCore(plugins: [DwSharedPreferences()]) — '
        'or hand DwAuthenticationKeyManager a store of your own.',
      );
    }
    return store;
  }

  int? get authKeyId {
    if (_authenticationKey == null) return null;
    final parts = _authenticationKey!.split(':');
    if (parts.length < 2) return null;
    return int.tryParse(parts.first);
  }

  @override
  Future<String?> get authHeaderValue async => toHeaderValue(await get());

  Future<String?> get() async {
    if (!_initialized) {
      _authenticationKey = await _storage.getString(
        '${_authKeyPrefsKey}_$runMode',
      );
      _initialized = true;
    }

    return _authenticationKey;
  }

  Future<void> put(String key) async {
    _authenticationKey = key;

    await _storage.setString('${_authKeyPrefsKey}_$runMode', key);
  }

  Future<void> remove() async {
    _authenticationKey = null;
    await _storage.remove('${_userProfilePrefsKey}_$runMode');
    await _storage.remove('${_authKeyPrefsKey}_$runMode');
  }

  Future<String?> toHeaderValue(String? key) async {
    if (key == null) return null;
    return wrapAsBearerAuthHeaderValue(key);
  }

  Future<(int?, UserProfileClass?)>
  loadLocalUserProfile<UserProfileClass extends SerializableModel>() async {
    try {
      final authKey = await get();
      if (authKey == null) return (null, null);

      final version = await _storage.getInt(
        '${_userProfilePrefsKey}_${runMode}_version',
      );

      final jsonString = await _storage.getString(
        '${_userProfilePrefsKey}_$runMode',
      );

      if (version != _prefsVersion || jsonString == null) {
        final userId = _tryExtractUserIdFromJson(jsonString);
        return (userId, null);
      }

      final json = jsonDecode(jsonString);

      return (
        json[DwCoreConst.userProfileIdColumnName] as int,
        DwCoreServerpodClient.protocol.deserialize<UserProfileClass>(json),
      );
    } catch (e) {
      final jsonString = await _storage
          .getString('${_userProfilePrefsKey}_$runMode')
          .catchError((_) => null);
      final userId = _tryExtractUserIdFromJson(jsonString);
      return (userId, null);
    }
  }

  int? _tryExtractUserIdFromJson(String? jsonString) {
    if (jsonString == null) return null;
    try {
      final json = jsonDecode(jsonString);
      return json[DwCoreConst.userProfileIdColumnName] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> storeUserProfile<UserProfileClass extends SerializableModel>(
    UserProfileClass userProfile,
  ) async {
    await _storage.setInt(
      '${_userProfilePrefsKey}_${runMode}_version',
      _prefsVersion,
    );

    // if (userProfile == null) {
    //   await _storage.remove('${_userProfilePrefsKey}_$runMode');
    // } else {
    await _storage.setString(
      '${_userProfilePrefsKey}_$runMode',
      SerializationManager.encode(userProfile),
    );
    // }
  }
}
