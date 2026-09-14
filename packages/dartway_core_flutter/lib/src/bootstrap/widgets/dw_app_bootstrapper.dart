import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:dartway_client/dartway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dw_flutter_core.dart';
import '../../private/dw_singleton.dart';
import '../dw_app_runner.dart';

/// The widget [DwAppRunner] mounts under its `ProviderScope`: runs the app's
/// initializers in order, shows [loadingScreen] meanwhile and the error screen
/// when one throws, then [child] — and puts `DwConfig.updateRequiredScreen`
/// over all of it once the core's client says this build can no longer talk
/// to its server.
///
/// Public so a widget test can mount the app exactly as the runner does,
/// without the runner's process-wide effects (bindings, error hooks, date
/// formatting): what a screen over everything looks like is decided here,
/// and a test that rebuilds it by hand checks a copy.
class DwAppBootstrapper extends ConsumerStatefulWidget {
  /// Run in order before [child] is shown; `null` runs none.
  final List<FutureOr<void> Function()>? appInitializers;

  /// Whether a native splash is on screen, to be removed once the
  /// initializers end.
  final bool useNativeSplash;

  /// Told about an initializer that threw. A handler that throws itself is
  /// logged; the error screen is shown either way.
  final void Function(Object error, StackTrace stackTrace) onError;

  /// The screen shown when an initializer threw, built from its error.
  final Widget Function(Object error, StackTrace stackTrace) errorScreenBuilder;

  /// Shown while the initializers run.
  final Widget loadingScreen;

  /// The app.
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
