import 'dart:async';

import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../dw_core.dart';
import '../router/router.dart';

/// Opens the screen a notification is about. The plugin holds the
/// notification that started the app until this listens, so a cold start
/// lands on it too; the router's guards send a signed-out user to sign in.
class PushOpenedListener extends ConsumerStatefulWidget {
  const PushOpenedListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushOpenedListener> createState() => _PushOpenedListenerState();
}

class _PushOpenedListenerState extends ConsumerState<PushOpenedListener> {
  StreamSubscription<DwPushOpened>? _opened;

  @override
  void initState() {
    super.initState();
    // Absent when push failed to start: the app runs without it.
    _opened = dw.plugins.maybeOf<DwPush>()?.opened.listen(_open);
  }

  void _open(DwPushOpened opened) {
    final router = ref.read(appRouterProvider).router;
    if (opened.payloadAs<NewsAlert>() != null) {
      router.goNamed(AppNavigationZone.news.name);
    } else if (opened.link case final link?) {
      router.go(link);
    }
  }

  @override
  void dispose() {
    unawaited(_opened?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
