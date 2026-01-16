import 'package:flutter/material.dart';

class AppSession extends ChangeNotifier {
  static final _instance = AppSession._();

  AppSession._();

  static AppSession get instance => _instance;

  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
