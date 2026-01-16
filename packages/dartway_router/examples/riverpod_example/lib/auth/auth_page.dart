import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_session_provider.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Auth Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            ref.read(isLoggedInProvider.notifier).state = true;
          },
          child: Text('Authorize'),
        ),
      ),
    );
  }
}
