/// Telegram Mini App integration for [DartWay](https://dartway.dev) apps.
///
/// Optional by construction: an app that is not a Mini App never depends on
/// this package, and `dartway_flutter` knows nothing about Telegram. The app
/// owns the bridge and starts it through the bootstrap seam it already has.
library;

export 'src/dw_telegram_platform.dart';
export 'src/dw_telegram_web_app.dart';
export 'src/dw_telegram_web_app_config.dart';
