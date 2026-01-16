import 'package:example/core/app_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this.ref) {
    _init();
  }

  final Ref ref;

  bool isLoggedIn = false;

  void _init() {
    // auth
    ref.listen<bool>(isLoggedInProvider, (_, next) {
      isLoggedIn = next;
      notifyListeners();
    }, fireImmediately: true);
  }
}
