import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dw_push.dart';

/// Starts push where the app actually exists — wrap it around the app's root,
/// under `ProviderScope`.
///
/// The plugin is declared at bootstrap, but nothing about push can happen
/// there: a permission prompt needs a screen to belong to, and a notification
/// tap needs an app to reach. This widget is that boundary. It attaches the
/// transport on mount, follows the signed-in user, and releases buffered taps
/// once there is a frame to route them into.
///
/// ```dart
/// DwPushScope(push: dw.plugins.push, child: MaterialApp.router(...))
/// ```
///
/// The plugin is passed in rather than looked up: `dw` belongs to the app, and
/// a package that reached for it would be assuming which app it is in.
class DwPushScope extends ConsumerStatefulWidget {
  const DwPushScope({super.key, required this.push, required this.child});

  final DwPush push;
  final Widget child;

  @override
  ConsumerState<DwPushScope> createState() => _DwPushScopeState();
}

class _DwPushScopeState extends ConsumerState<DwPushScope> {
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    final recipientIdProvider = widget.push.config.recipientIdProvider;
    if (recipientIdProvider != null) {
      widget.push.setRecipient(ref.read(recipientIdProvider));
    }
    unawaited(_start());
  }

  Future<void> _start() async {
    await widget.push.attach();
    if (_isDisposed) return;
    widget.push.markReadyForOpens(_runAfterFrame);
  }

  /// Runs [action] once the frame is done — and asks for that frame.
  ///
  /// A tap on a notification while the app is on screen changes no widget, so
  /// Flutter has no reason to schedule a frame, and a post-frame callback
  /// registered without one simply waits until the user touches something
  /// else. The navigation would then land minutes later, on an unrelated
  /// gesture.
  void _runAfterFrame(void Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      action();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(widget.push.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipientIdProvider = widget.push.config.recipientIdProvider;
    if (recipientIdProvider != null) {
      ref.listen<int?>(
        recipientIdProvider,
        (_, recipientId) => widget.push.setRecipient(recipientId),
      );
    }
    return widget.child;
  }
}
