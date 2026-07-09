import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../error_reporting/dw_error_report.dart';
import '../private/dw_singleton.dart';
import 'logic/dw_app_loading_options.dart';
import 'widgets/dw_app_bootstrapper.dart';

/// Default zone handler: routes uncaught errors into the dw error pipeline
/// (context capture + configured handlers / out-of-the-box alerting). Falls
/// back to debugPrint while dw is not created yet (early bootstrap).
void _routeErrorToDw(Object error, StackTrace stackTrace) {
  final instance = dwOrNull;
  if (instance != null) {
    instance.handleError(error, stackTrace, source: DwErrorSource.zone);
  } else {
    debugPrint('[DwAppRunner ERROR] $error');
    debugPrint(stackTrace.toString());
  }
}

/// A universal application bootstrapper for Flutter + Riverpod apps.
///
/// Responsibilities:
/// - Initialize Flutter bindings
/// - Manage optional native splash screen
/// - Initialize locale/date formatting
/// - Execute ordered async initializers
/// - Provide a global error pipeline (FlutterError + PlatformDispatcher)
/// - Render loading/error screens during initialization
///
/// This class is intentionally decoupled from DartWay Core.
/// If you use Dw/DwCore, simply include `Dw.init()` inside `appInitializers`.
class DwAppRunner {
  /// Optional sequence of initialization steps.
  /// Each must return `true` to continue the pipeline.
  final List<FutureOr<void> Function()>? appInitializers;

  /// Loading/error screen configuration.
  final DwAppLoadingOptions appLoadingOptions;

  /// Locales used for initializing date/number formatting.
  /// Also useful for MaterialApp.supportedLocales.
  final List<Locale> supportedLocales;

  /// Optional custom global error handler. When omitted, uncaught errors go
  /// through the dw error pipeline (`dw.handleError` with zone source) — with
  /// DwCore that means out-of-the-box alerting with app context.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// The actual app widget.
  final Widget child;

  const DwAppRunner({
    required this.child,
    this.onError,
    this.appInitializers,
    this.appLoadingOptions = const DwAppLoadingOptions.withNativeSplash(),
    this.supportedLocales = const [],
  });

  // ---------------------------------------------------------------------------
  // Pre-initialization: binding, splash, routing
  // ---------------------------------------------------------------------------
  WidgetsBinding _preInit() {
    final binding = WidgetsFlutterBinding.ensureInitialized();

    if (appLoadingOptions.useNativeSplash) {
      FlutterNativeSplash.preserve(widgetsBinding: binding);
    }

    return binding;
  }

  void run() {
    final binding = _preInit();

    final effectiveOnError = onError ?? _routeErrorToDw;

    // Global error pipeline WITHOUT a custom error zone. A guarded zone makes
    // `runApp` run in a different zone than the binding was initialized in
    // (notably on web), triggering Flutter's "Zone mismatch" warning.
    // FlutterError.onError covers framework errors; platformDispatcher.onError
    // catches uncaught async errors that reach the root zone — the modern,
    // zone-safe equivalent of runZonedGuarded.
    FlutterError.onError = (FlutterErrorDetails details) {
      effectiveOnError(details.exception, details.stack ?? StackTrace.empty);
    };
    binding.platformDispatcher.onError = (error, stack) {
      effectiveOnError(error, stack);
      return true;
    };

    final initializers = [
      () async {
        for (final locale in supportedLocales) {
          await initializeDateFormatting(locale.languageCode);
        }
        return true;
      },
      if (appInitializers != null) ...appInitializers!,
    ];

    runApp(
      ProviderScope(
        child: DwAppBootstrapper(
          appInitializers: initializers,
          useNativeSplash: appLoadingOptions.useNativeSplash,
          onError: effectiveOnError,
          errorScreen: appLoadingOptions.errorScreen,
          loadingScreen: appLoadingOptions.loadingScreen,
          child: child,
        ),
      ),
    );
  }
}
