import 'package:flutter/material.dart';

/// Mock router state for testing
class MockRouterState extends ChangeNotifier {
  bool isAuthorized = false;
  bool isLoggedIn = false;

  void authorize() {
    isAuthorized = true;
    notifyListeners();
  }

  void logout() {
    isAuthorized = false;
    isLoggedIn = false;
    notifyListeners();
  }
}

/// Test page widget
class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('Test Page'),
    );
  }
}
