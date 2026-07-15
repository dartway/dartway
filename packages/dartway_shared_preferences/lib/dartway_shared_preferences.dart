/// Shared-preferences plugin for [DartWay](https://dartway.dev) apps.
///
/// Optional by construction: an app that needs no local storage never depends
/// on this package, and `dartway_flutter` knows nothing about it. Declare the
/// plugin at startup and reach it as `dw.plugins.prefs`.
library;

export 'src/dw_shared_preferences.dart';
export 'src/dw_shared_preferences_plugin.dart';
