// -----------------------------------------------------------------------------
// ROOT STATE MACHINE (initializing → loading → error → ready)
// -----------------------------------------------------------------------------
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DwAppBootstrapper extends ConsumerStatefulWidget {
  final List<FutureOr<void> Function(WidgetRef ref)>? appInitializers;

  final void Function(Object error, StackTrace stackTrace) onError;
  final Widget errorScreen;
  final Widget loadingScreen;
  final Widget child;

  const DwAppBootstrapper({
    super.key,
    required this.appInitializers,
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
      // -----------------------------------------------------------------------
      // 1. Locale & date formatting initialization
      // -----------------------------------------------------------------------
      // for (final locale in widget.supportedLocales) {
      //   await initializeDateFormatting(locale.languageCode);
      // }

      // -----------------------------------------------------------------------
      // 2. Run user-defined initializers (Dw.init, analytics, cache, DB, etc.)
      // -----------------------------------------------------------------------
      if (widget.appInitializers != null) {
        for (final init in widget.appInitializers!) {
          await init(ref);
        }
      }

      // -----------------------------------------------------------------------
      // 3. Remove splash
      // -----------------------------------------------------------------------
      // if (widget.appLoadingOptions.useNativeSplash) {
      //   FlutterNativeSplash.remove();
      // }

      // Done
      setState(() => _initialized = true);
    } catch (error, stack) {
      widget.onError(error, stack);
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.errorScreen;
    if (!_initialized) return widget.loadingScreen;

    return widget.child;
  }
}
