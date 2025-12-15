// // This file includes code derived from the Serverpod project (https://github.com/serverpod/serverpod).
// // Copyright (c) 2020 Serverpod. All rights reserved.
// // Modified by Evgenii Novikov for DartWay.dev under the Apache License 2.0.

// import 'dart:async';
// import 'dart:convert';

// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:flutter/cupertino.dart';

// const _prefsKey = 'serverpod_userinfo_key';
// const _prefsVersion = 2;

// /// The [SessionManager] keeps track of and manages the signed-in state of the
// /// user. Use the [instance] method to get access to the singleton instance.
// /// Users are typically authenticated with Google, Apple, or other methods.
// /// Please refer to the documentation to see supported methods. Session
// /// information is stored in the shared preferences of the app and persists
// /// between restarts of the app.
// class SessionManager<UserProfileClass extends SerializableModel>
//     with ChangeNotifier {
//   static SessionManager? _instance;

//   /// The auth module's caller.
//   // Caller caller;
//   ServerpodClientShared client;

//   /// The key manager, holding the key's of the user, if signed in.
//   late DwAuthenticationKeyManager keyManager;

//   final Storage _storage;

//   /// Creates a new session manager.
//   SessionManager({required this.client, Storage? storage})
//     : _storage = storage ?? SharedPreferenceStorage() {
//     _instance = this;
//     assert(
//       client.authenticationKeyManager != null,
//       'The client needs an associated key manager',
//     );
//     keyManager = client.authenticationKeyManager! as DwAuthenticationKeyManager;
//   }

//   /// Returns a singleton instance of the session manager
//   static Future<SessionManager> get instance async {
//     assert(
//       _instance != null,
//       'You need to create a SessionManager before the instance method can be called',
//     );
//     return _instance!;
//   }

//   UserProfileClass? _signedInUser;

//   /// Returns information about the signed in user or null if no user is
//   /// currently signed in.
//   UserProfileClass? get signedInUser => _signedInUser;

//   /// Registers the signed in user, updates the [keyManager], and upgrades the
//   /// streaming connection if it is open.
//   Future<void> registerSignedInUser(
//     UserProfileClass userInfo,
//     int authenticationKeyId,
//     String authenticationKey,
//   ) async {
//     _signedInUser = userInfo;
//     var key = '$authenticationKeyId:$authenticationKey';

//     // Store in key manager.
//     await keyManager.put(key);
//     await _storeSharedPrefs();

//     // Update streaming connection, if it's open.
//     await client.updateStreamingConnectionAuthenticationKey(key);
//     notifyListeners();
//   }

//   /// Returns true if the user is currently signed in.
//   bool get isSignedIn => signedInUser != null;

//   /// Initializes the session manager by reading the current state from
//   /// shared preferences. The returned bool is true if the session was
//   /// initialized, or false if the server could not be reached.
//   Future<bool> initialize() async {
//     await _loadSharedPrefs();
//     return refreshSession();
//   }

//   /// Signs the user out from their devices.
//   /// If [allDevices] is true, signs out from all devices; otherwise, signs out from the current device only.
//   /// Returns true if the sign-out is successful.
//   Future<bool> _signOut({required bool allDevices}) async {
//     if (!isSignedIn) return true;

//     try {
//       /// TODO: Auth Rework

//       // if (allDevices) {
//       //   await caller.status.signOutAllDevices();
//       // } else {
//       //   await caller.status.signOutDevice();
//       // }
//       await client.updateStreamingConnectionAuthenticationKey(null);

//       _signedInUser = null;
//       await _storeSharedPrefs();
//       await keyManager.remove();

//       notifyListeners();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// **[Deprecated]** Signs the user out from all connected devices.
//   /// Use `signOutDevice` for the current device or `signOutAllDevices` for all devices.
//   /// Returns true if successful.
//   @Deprecated(
//     'Use signOutDevice for the current device or signOutAllDevices for all devices. This method will be removed in future releases.',
//   )
//   Future<bool> signOut() async {
//     return _signOut(allDevices: true);
//   }

//   /// Signs the user out from all connected devices.
//   /// Returns true if successful.
//   Future<bool> signOutAllDevices() async {
//     return _signOut(allDevices: true);
//   }

//   /// Signs the user out from the current device.
//   /// Returns true if successful.
//   Future<bool> signOutDevice() async {
//     return _signOut(allDevices: false);
//   }

//   /// Verify the current sign in status with the server and update the UserInfo.
//   /// Returns true if successful.
//   Future<bool> refreshSession() async {
//     try {
//       /// TODO: Auth Rework
//       // _signedInUser = await caller.status.getUserInfo();
//       await _storeSharedPrefs();
//       notifyListeners();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<void> _loadSharedPrefs() async {
//     var version = await _storage.getInt(
//       '${_prefsKey}_${keyManager.runMode}_version',
//     );
//     if (version != _prefsVersion) return;

//     var json = await _storage.getString('${_prefsKey}_${keyManager.runMode}');
//     if (json == null) return;

//     _signedInUser = Protocol().deserialize<UserProfileClass>(jsonDecode(json));

//     notifyListeners();
//   }

//   Future<void> _storeSharedPrefs() async {
//     await _storage.setInt(
//       '${_prefsKey}_${keyManager.runMode}_version',
//       _prefsVersion,
//     );
//     if (signedInUser == null) {
//       await _storage.remove('${_prefsKey}_${keyManager.runMode}');
//     } else {
//       await _storage.setString(
//         '${_prefsKey}_${keyManager.runMode}',
//         SerializationManager.encode(signedInUser),
//       );
//     }
//   }

//   /// Uploads a new user image if the user is signed in. Returns true if upload
//   /// was successful.
//   // Future<bool> uploadUserImage(ByteData image) async {
//   //   if (_signedInUser == null) return false;

//   //   try {
//   //     var success = await caller.user.setUserImage(image);
//   //     if (success) {
//   //       _signedInUser = await caller.status.getUserInfo();

//   //       notifyListeners();
//   //       return true;
//   //     }
//   //     return false;
//   //   } catch (e) {
//   //     return false;
//   //   }
//   // }
// }
