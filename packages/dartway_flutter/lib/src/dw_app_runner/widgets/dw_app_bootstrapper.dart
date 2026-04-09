// -----------------------------------------------------------------------------
// ROOT STATE MACHINE (initializing → loading → error → ready)
// -----------------------------------------------------------------------------
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DwAppBootstrapper extends ConsumerStatefulWidget {
  final List<FutureOr<void> Function()>? appInitializers;
  final bool useNativeSplash;

  final void Function(Object error, StackTrace stackTrace) onError;
  final Widget errorScreen;
  final Widget loadingScreen;
  final Widget child;

  const DwAppBootstrapper({
    super.key,
    required this.appInitializers,
    required this.useNativeSplash,
    required this.onError,
    required this.errorScreen,
    required this.loadingScreen,
    required this.child,
  });

  @override
  ConsumerState<DwAppBootstrapper> createState() => DwAppRootState();
}

class DwAppRootState extends ConsumerState<DwAppBootstrapper> {
  bool _initialized = false;
  bool _failed = false;

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
      widget.onError(error, stack);
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (widget.useNativeSplash) {
        FlutterNativeSplash.remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.errorScreen;
    if (!_initialized) return widget.loadingScreen;

    return widget.child;
  }
}
