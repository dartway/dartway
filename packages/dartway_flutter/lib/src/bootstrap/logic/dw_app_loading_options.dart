import 'package:flutter/material.dart';

/// What the app shows while it is starting, and what it shows when it cannot.
class DwAppLoadingOptions {
  /// The screen a failed start lands on: the message, and the failure itself.
  ///
  /// The error text is on the screen deliberately. A start can fail for
  /// reasons only the failure names — a missing configuration, an unreachable
  /// server, a plugin that threw — and the person looking at the screen is
  /// usually the one who will be asked what happened. "Please contact
  /// administrator" with nothing else turns a reportable fault into "the app
  /// is broken".
  static Widget defaultErrorScreen(Object error, StackTrace stackTrace) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF1C1C1E),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The app could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  const DwAppLoadingOptions.withoutNativeSplash({
    this.loadingScreen = const Center(child: CircularProgressIndicator()),
    this.errorScreenBuilder = defaultErrorScreen,
  }) : useNativeSplash = false;

  const DwAppLoadingOptions.withNativeSplash({
    this.errorScreenBuilder = defaultErrorScreen,
  }) : loadingScreen = const SizedBox.shrink(),
       useNativeSplash = true;

  /// Builds the screen for a start that failed, from the error that failed it.
  final Widget Function(Object error, StackTrace stackTrace) errorScreenBuilder;

  final Widget loadingScreen;
  final bool useNativeSplash;
}
