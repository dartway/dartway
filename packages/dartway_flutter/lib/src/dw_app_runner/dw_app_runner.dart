import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'logic/dw_app_loading_options.dart';
import 'logic/dw_routing_config.dart';
import 'widgets/dw_app_bootstrapper.dart';

// Default fallback if user does not provide an error handler.
void _defaultErrorHandler(Object error, StackTrace stackTrace) {
  debugPrint('[DwAppRunner ERROR] $error');
  debugPrint(stackTrace.toString());
}

/// A universal application bootstrapper for Flutter + Riverpod apps.
///
/// Responsibilities:
/// - Initialize Flutter bindings
/// - Manage optional native splash screen
/// - Initialize locale/date formatting
/// - Execute ordered async initializers
/// - Provide a global error pipeline (FlutterError + Zone)
/// - Render loading/error screens during initialization
///
/// This class is intentionally decoupled from DartWay Core.
/// If you use Dw/DwCore, simply include `Dw.init()` inside `appInitializers`.
class DwAppRunner {
  /// Optional sequence of initialization steps.
  /// Each must return `true` to continue the pipeline.
  final List<FutureOr<void> Function(WidgetRef ref)>? appInitializers;

  /// Optional routing configuration (e.g., GoRouter, custom setup).
  final DwRoutingConfig routingOptions;

  /// Loading/error screen configuration.
  final DwAppLoadingOptions appLoadingOptions;

  /// Locales used for initializing date/number formatting.
  /// Also useful for MaterialApp.supportedLocales.
  final List<Locale> supportedLocales;

  /// Optional custom global error handler.
  final void Function(Object error, StackTrace stackTrace) onError;

  /// The actual app widget.
  final Widget child;

  const DwAppRunner({
    required this.child,
    this.onError = _defaultErrorHandler,
    this.appInitializers,
    this.routingOptions = const DwRoutingConfig(),
    this.appLoadingOptions = const DwAppLoadingOptions.withNativeSplash(),
    this.supportedLocales = const [],
  });

  // ---------------------------------------------------------------------------
  // Pre-initialization: binding, splash, routing
  // ---------------------------------------------------------------------------
  void _preInit() {
    final binding = WidgetsFlutterBinding.ensureInitialized();

    if (appLoadingOptions.useNativeSplash) {
      FlutterNativeSplash.preserve(widgetsBinding: binding);
    }

    routingOptions.init();
  }

  void run() {
    // TODO: clarify if this is the best way to handle errors
    runZonedGuarded(
      () {
        _preInit();

        // Handle Flutter framework errors
        FlutterError.onError = (FlutterErrorDetails details) {
          onError(details.exception, details.stack ?? StackTrace.empty);
        };

        final initializers = [
          (_) async {
            for (final locale in supportedLocales) {
              await initializeDateFormatting(locale.languageCode);
            }
            return true;
          },
          if (appInitializers != null) ...appInitializers!,
          if (appLoadingOptions.useNativeSplash)
            (_) async {
              FlutterNativeSplash.remove();
              return true;
            },
        ];

        runApp(
          ProviderScope(
            child: DwAppBootstrapper(
              appInitializers: initializers,
              onError: onError,
              errorScreen: appLoadingOptions.errorScreen,
              loadingScreen: appLoadingOptions.loadingScreen,
              child: child,
            ),
          ),
        );
      },
      (error, stackTrace) {
        onError(error, stackTrace);
      },
    );
  }
}
