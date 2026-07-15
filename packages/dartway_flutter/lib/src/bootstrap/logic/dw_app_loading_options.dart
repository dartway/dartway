import 'package:flutter/material.dart';

class DwAppLoadingOptions {
  static const defaultErrorScreen = Center(
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Text('App initialization failed, please, contact administrator'),
      ),
    ),
  );

  const DwAppLoadingOptions.withoutNativeSplash({
    this.loadingScreen = const Center(child: CircularProgressIndicator()),
    this.errorScreen = defaultErrorScreen,
  }) : useNativeSplash = false;

  const DwAppLoadingOptions.withNativeSplash({
    this.errorScreen = defaultErrorScreen,
  }) : loadingScreen = const SizedBox.shrink(),
       useNativeSplash = true;

  final Widget errorScreen;
  final Widget loadingScreen;
  final bool useNativeSplash;
}
