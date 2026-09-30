import 'dart:async';

import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../dw_core.dart';
import '../router/router.dart';

/// Opens the screen a notification is about. The plugin holds the
/// notification that started the app until this listens, so a cold start
/// lands on it too; the router's guards send a signed-out user to sign in.
class PushOpenedListener extends HookConsumerWidget {
  const PushOpenedListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      // Absent when push failed to start: the app runs without it.
      final opened = dw.plugins.maybeOf<DwPush>()?.opened.listen((opened) {
        final router = ref.read(appRouterProvider).router;
        if (opened.payloadAs<NewsAlert>() != null) {
          router.goNamed(AppNavigationZone.news.name);
        } else if (opened.link case final link?) {
          router.go(link);
        }
      });
      return () => unawaited(opened?.cancel());
    }, const []);
    return child;
  }
}
