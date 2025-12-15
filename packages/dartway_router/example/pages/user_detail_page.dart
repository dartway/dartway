import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';

class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the user ID from navigation parameters
    final userId = ref.watchNavigationParam(AppParams.userId) ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text('User $userId')),
      body: Center(
        child: Text('User Detail for ID: $userId'),
      ),
    );
  }
}
