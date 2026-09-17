import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Calls the page's `removeSplashFromWeb()` when its shell defines one — the
/// function `flutter_native_splash` writes into a generated `index.html`.
class DwWebSplash {
  const DwWebSplash._();

  static void remove() {
    if (!globalContext.has('removeSplashFromWeb')) return;
    globalContext.callMethod('removeSplashFromWeb'.toJS);
  }
}
