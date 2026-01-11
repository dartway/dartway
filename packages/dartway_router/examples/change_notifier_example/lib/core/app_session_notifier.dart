import 'package:flutter/material.dart';

class AppSession extends ChangeNotifier {
  static final _instance = AppSession._();

  AppSession._();

  static AppSession get instance => _instance;

  bool _isAuthorized = false;

  bool get isAuthorized => _isAuthorized;

  void authorize() {
    _isAuthorized = true;
    notifyListeners();
  }

  void logout() {
    _isAuthorized = false;
    notifyListeners();
  }
}
