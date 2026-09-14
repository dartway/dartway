import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:dartway_client/dartway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dw_flutter_core.dart';
import '../../private/dw_singleton.dart';

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

  /// Why this build can no longer talk to its server, once the data layer
  /// says so.
  DwCallRefusal? _incompatibility;
  StreamSubscription<DwCallRefusal?>? _incompatibilitySubscription;

  @override
  void initState() {
    super.initState();
    _watchCompatibility();
    _runInitializers();
  }

  @override
  void dispose() {
    unawaited(_incompatibilitySubscription?.cancel());
    super.dispose();
  }

  /// Follows the data layer's incompatibility when the app has a page for it.
  /// Called at start and again after the initializers, for an app that builds
  /// its core in one of them.
  void _watchCompatibility() {
    if (_incompatibilitySubscription != null) return;
    final core = dwOrNull;
    if (core is! DwFlutterCore || core.config.updateRequiredScreen == null) {
      return;
    }
    _incompatibilitySubscription = core.client.incompatibilityStream.listen((
      refusal,
    ) {
      if (mounted && refusal != _incompatibility) {
        setState(() => _incompatibility = refusal);
      }
    });
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
        _watchCompatibility();
        setState(() => _initialized = true);
      }
    } catch (error, stack) {
      // Reporting is attempted, and it is not allowed to decide whether the
      // app gets a first frame. The handler runs against a core that has just
      // failed to initialize — DwFlutterCore's own alerting talks to the server the
      // start could not reach — and a throw in here used to leave `_failed`
      // unset, so the app sat on the loading screen, which under a native
      // splash is a `SizedBox.shrink()`: nothing at all, for good.
      try {
        widget.onError(error, stack);
      } catch (reportingError, reportingStack) {
        debugPrint(
          '[DwAppBootstrapper] the error report itself failed: '
          '$reportingError\n$reportingStack',
        );
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
    // Over everything, the loading and error screens included: nothing under
    // it can reach the server any more, and only another build can.
    final incompatibility = _incompatibility;
    final updateScreen = dwOrNull?.config.updateRequiredScreen;
    if (incompatibility != null && updateScreen != null) {
      return updateScreen(context, incompatibility);
    }
    final failure = _failure;
    if (failure != null) {
      return widget.errorScreenBuilder(failure.$1, failure.$2);
    }
    if (!_initialized) return widget.loadingScreen;

    return widget.child;
  }
}
