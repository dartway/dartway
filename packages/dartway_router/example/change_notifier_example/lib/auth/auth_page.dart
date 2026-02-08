import 'package:flutter/material.dart';

import '../core/app_session_notifier.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Auth Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            AppSession.instance.login();
          },
          child: Text('Authorize'),
        ),
      ),
    );
  }
}
