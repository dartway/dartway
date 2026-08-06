// Application code. A ProviderScope here is the trap the rule exists for: the
// override is read by widgets under the scope and missed by any provider that
// reaches the same provider through its own Ref.
//
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final greetingProvider = Provider<String>((ref) => 'root');

class ScopedGreeting extends StatelessWidget {
  const ScopedGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: forbidden_provider_scope
    return ProviderScope(
      overrides: [greetingProvider.overrideWithValue('scoped')],
      child: const SizedBox.shrink(),
    );
  }
}

class ConstScopedGreeting extends StatelessWidget {
  const ConstScopedGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    // A const scope carries no overrides and so traps nobody today — but it is
    // one edit away from carrying them, and the rule is about the shape.
    // expect_lint: forbidden_provider_scope
    return const ProviderScope(child: SizedBox.shrink());
  }
}

/// The root scope is not an exception either: `DwAppRunner` already creates one
/// around the whole app, so an app writing its own is either duplicating it or
/// bypassing the bootstrap.
void main() {
  // expect_lint: forbidden_provider_scope
  runApp(const ProviderScope(child: SizedBox.shrink()));
}
