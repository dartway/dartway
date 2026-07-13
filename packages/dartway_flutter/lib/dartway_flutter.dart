// lib/dartway_flutter.dart
//
// The Flutter skeleton of a DartWay app: bootstrap, ambient app core, the
// async-UI contract, actions, notifications, error reporting and features.
//
// It deliberately ships no design — no button, no text widget, no theme, no
// style presets. Those belong to the app's own `ui_kit/`, which `dartway create`
// scaffolds and the app then owns outright. What the framework does ship is the
// mechanism an app should not have to reinvent: `DwActionBuilder` guards a
// `DwUiAction` behind any tappable widget, and `dwBuildAsync` renders
// loading/error/data uniformly.

// Feature declarations: mark a widget as a product feature (DwFeature) and
// discover the mounted ones at runtime — feature catalogs, error-report
// context, analytics; the app's Studio binding maps them onto the bridge.
export 'src/features/dw_feature.dart';
export 'src/features/dw_feature_scanner.dart';
export 'src/features/dw_feature_spec.dart';

// DwApp configuration
export 'src/dw/configs/dw_config.dart';
export 'src/dw/dw.dart';
// Plugins: integrations the framework must not know about (Telegram, analytics,
// …). Declared at startup, reached anywhere via `dw.plugin<T>()`.
export 'src/dw/dw_plugin.dart';
// Error reporting: app-state context captured into every error report.
export 'src/error_reporting/dw_error_context.dart';
export 'src/error_reporting/dw_error_report.dart';
// App initialization
export 'src/dw_app_runner/dw_app_runner.dart';
export 'src/dw_app_runner/logic/dw_app_loading_options.dart';
// Notifications
export 'src/notifications/domain/dw_ui_notification.dart';
export 'src/notifications/ui/dw_notifications_listener.dart';
export 'src/notifications/ui/dw_ui_notification_handler.dart';
// Confirmation: the declarative request, plus the built-in dialog used when the
// app has not supplied `DwConfig.confirmDialogBuilder`.
export 'src/dialogs/dw_ui_confirmation.dart';
// Lists
export 'src/lists/infinite_list_view/domain/dw_infinite_list_view_config.dart';
export 'src/lists/infinite_list_view/domain/dw_infinite_list_view_grouped_item.dart';
export 'src/lists/infinite_list_view/infinite_list_view.dart';
// Actions: the policy (DwUiAction) and the widget-agnostic guard that runs it.
export 'src/utils/dw_action_builder.dart';
export 'src/utils/dw_ui_action.dart';
// AsyncValue utilities
export 'src/utils/dw_async_value_extension.dart';
export 'src/utils/dw_build_async_list_value_extension.dart';
