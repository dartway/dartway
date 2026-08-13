/// Push notifications for a DartWay app — `dw.plugins.push`.
///
/// This package carries no vendor SDK. Add a transport alongside it:
/// `dartway_push_firebase`, `dartway_push_rustore`, or one of your own.
library;

export 'src/dw_push.dart';
export 'src/dw_push_config.dart';
export 'src/dw_push_notification.dart';
export 'src/dw_push_provider.dart';
export 'src/dw_push_scope.dart';
export 'src/logic/dw_push_token_sync.dart' show DwPushTokenRegistrar;
