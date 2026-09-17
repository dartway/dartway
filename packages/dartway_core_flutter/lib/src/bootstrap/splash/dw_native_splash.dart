import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'dw_web_splash_stub.dart'
    if (dart.library.js_interop) 'dw_web_splash_web.dart';

/// Keeps the platform's splash up until the app has bootstrapped.
///
/// What `flutter_native_splash` does at run time, without it: that package is
/// a generator, and depending on it at run time put `image`, `archive` and
/// their dependencies into every app's graph (#268). Holding the first frame
/// is the binding's own `deferFirstFrame`; on the web the page's
/// `removeSplashFromWeb()`, when a generated shell defines one, is called
/// after the first frame. The template's shell removes its splash itself on
/// `flutter-first-frame` and defines none.
class DwNativeSplash {
  const DwNativeSplash._();

  static WidgetsBinding? _binding;

  static void preserve(WidgetsBinding binding) {
    _binding = binding..deferFirstFrame();
  }

  static void remove() {
    final binding = _binding;
    if (binding == null) return;
    _binding = null;
    binding.allowFirstFrame();
    if (kIsWeb) {
      binding.addPostFrameCallback((_) => DwWebSplash.remove());
    }
  }
}
