// This file includes code derived from the Serverpod project (https://github.com/serverpod/serverpod).
// Copyright (c) 2020 Serverpod. All rights reserved.
// Modified by Evgenii Novikov for DartWay.dev under the Apache License 2.0.

import 'dart:convert';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dw_auth_storage_interface.dart';

const _authKeyPrefsKey = 'dartway_authentication_key';
const _userProfilePrefsKey = 'dw_user_profile_key';
const _prefsVersion = 1;

/// Implementation of a Serverpod [AuthenticationKeyManager] specifically for
/// Flutter. Authentication key is stored in the [SharedPreferences].
class DwAuthenticationKeyManager extends AuthenticationKeyManager {
  bool _initialized = false;
  String? _authenticationKey;

  /// The run mode of the Serverpod.
  final String runMode;

  final Storage _storage;

  /// Creates a new authentication key manager. By default it uses the
  /// shared preferences for storing keys.
  DwAuthenticationKeyManager({this.runMode = 'production', Storage? storage})
    : _storage = storage ?? SharedPreferenceStorage();

  int? get authKeyId =>
      _authenticationKey != null
          ? int.tryParse(_authenticationKey!.split(':').first)
          : null;

  @override
  Future<String?> get() async {
    if (!_initialized) {
      _authenticationKey = await _storage.getString(
        '${_authKeyPrefsKey}_$runMode',
      );
      _initialized = true;
    }

    return _authenticationKey;
  }

  @override
  Future<void> put(String key) async {
    _authenticationKey = key;

    await _storage.setString('${_authKeyPrefsKey}_$runMode', key);
  }

  @override
  Future<void> remove() async {
    _authenticationKey = null;
    await _storage.remove('${_userProfilePrefsKey}_$runMode');
    await _storage.remove('${_authKeyPrefsKey}_$runMode');
  }

  Future<(int?, UserProfileClass?)>
  loadLocalUserProfile<UserProfileClass extends SerializableModel>() async {
    try {
      await get();

      final version = await _storage.getInt(
        '${_userProfilePrefsKey}_${runMode}_version',
      );
      if (version != _prefsVersion) return (null, null);

      final jsonString = await _storage.getString(
        '${_userProfilePrefsKey}_$runMode',
      );
      if (jsonString == null) return (null, null);

      final json = jsonDecode(jsonString);

      return (
        json[DwCoreConst.userProfileIdColumnName] as int,
        DwCoreServerpodClient.protocol.deserialize<UserProfileClass>(json),
      );
    } catch (e) {
      return (null, null);
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
