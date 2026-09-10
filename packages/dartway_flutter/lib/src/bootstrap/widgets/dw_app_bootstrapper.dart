import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DwAppBootstrapper extends ConsumerStatefulWidget {
  final List<FutureOr<void> Function()>? appInitializers;
  final bool useNativeSplash;

  final void Function(Object error, StackTrace stackTrace) onError;
  final Widget Function(Object error, StackTrace stackTrace) errorScreenBuilder;
  final Widget loadingScreen;
  final Widget child;

  const DwAppBootstrapper({
    super.key,
    required this.appInitializers,
    required this.useNativeSplash,
    required this.onError,
    required this.errorScreenBuilder,
    required this.loadingScreen,
    required this.child,
  });

  @override
  ConsumerState<DwAppBootstrapper> createState() => _DwAppBootstrapperState();
}

class _DwAppBootstrapperState extends ConsumerState<DwAppBootstrapper> {
  bool _initialized = false;
  (Object, StackTrace)? _failure;

  @override
  void initState() {
    super.initState();
    _runInitializers();
  }

  // Executes initialization pipeline
  Future<void> _runInitializers() async {
    try {
      if (widget.appInitializers != null) {
        for (final init in widget.appInitializers!) {
          await init();
        }
      }

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (error, stack) {
      // Reporting is attempted, and it is not allowed to decide whether the
      // app gets a first frame. The handler runs against a core that has just
      // failed to initialize — DwCore's own alerting talks to the server the
      // start could not reach — and a throw in here used to leave `_failed`
      // unset, so the app sat on the loading screen, which under a native
      // splash is a `SizedBox.shrink()`: nothing at all, for good.
      try {
        widget.onError(error, stack);
      } catch (reportingError, reportingStack) {
        debugPrint('[DwAppBootstrapper] the error report itself failed: '
            '$reportingError\n$reportingStack');
      }
      if (mounted) {
        setState(() => _failure = (error, stack));
      }
    } finally {
      if (widget.useNativeSplash) {
        FlutterNativeSplash.remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return widget.errorScreenBuilder(failure.$1, failure.$2);
    }
    if (!_initialized) return widget.loadingScreen;

    return widget.child;
  }
}
