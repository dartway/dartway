/// The pure-Dart layer shared by the DartWay server and the DartWay Flutter
/// app: the wire contract both sides must agree on, and the alerts sink that
/// reports runtime errors from either of them.
///
/// Apps rarely depend on this package directly — it arrives with
/// `dartway_serverpod_core_server` or `dartway_serverpod_core_flutter`, both of
/// which re-export it.
library;

export 'src/alerts/configs/dw_telegram_alerts_config.dart';
export 'src/alerts/configs/dw_telegram_alerts_keys.dart';
export 'src/alerts/dw_alert_context.dart';
export 'src/alerts/dw_alerts.dart';
export 'src/static/dw_core_const.dart';

