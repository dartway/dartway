// lib/dartway_flutter.dart
//
// The Flutter skeleton of a DartWay app: bootstrap, the ambient app core, the
// async-UI contract, actions, notifications, error reporting, features and the
// plugin seam.
//
// It deliberately ships no design — no button, no text widget, no theme, no
// style presets. Those belong to the app's own `ui_kit/`, which `dartway create`
// scaffolds and the app then owns outright. What the framework ships is the
// mechanism an app should not have to reinvent: `dw.action` guards a
// `DwUiAction` behind any tappable widget, and `dwBuildAsync` renders
// loading/error/data uniformly. See DESIGN.md for the design principles.
//
// lib/src is grouped into: core (the ambient dw + config + plugins), bootstrap
// (app runner), ui (actions, async_ui, notifications, confirmation) and
// diagnostics (error reporting, feature declarations).

// core: the ambient app root, its config, and the plugin registry
// (`dw.plugins.<name>`).
export 'src/core/dw_flutter.dart';
export 'src/core/logic/dw_config.dart';
export 'src/core/logic/dw_plugin.dart';

// bootstrap: ProviderScope, native splash, ordered initializers, the global
// error pipeline.
export 'src/bootstrap/dw_app_runner.dart';
export 'src/bootstrap/logic/dw_app_loading_options.dart';

// ui/actions: the policy (DwUiAction, built via `dw.action`) and the
// widget-agnostic guard that runs it.
export 'src/ui/actions/dw_ui_action.dart';
export 'src/ui/actions/widgets/dw_action_builder.dart';

// ui/async_ui: render loading/error/data uniformly, with skeletons.
export 'src/ui/async_ui/dw_async_ui.dart';

// ui/notifications: post a DwUiNotification from anywhere (`dw.notify.*`),
// render it with your own handler.
export 'src/ui/notifications/dw_ui_notification.dart';
export 'src/ui/notifications/logic/dw_notification_handler.dart';
export 'src/ui/notifications/widgets/dw_notifications_listener.dart';
export 'src/ui/notifications/widgets/dw_ui_notification_handler.dart';

// ui/confirmation: the declarative request, plus the built-in dialog used when
// the app has not supplied `DwConfig.confirmDialogBuilder`.
export 'src/ui/confirmation/dw_ui_confirmation.dart';

// diagnostics/error_reporting: app-state context captured into every report.
// dw_error_report re-exports the source enum and the context snapshot.
export 'src/diagnostics/error_reporting/dw_error_report.dart';

// diagnostics/dw_feature: mark a widget as a product feature and discover the
// mounted ones at runtime — feature catalogs, error context, Studio passports.
export 'src/diagnostics/dw_feature/dw_feature.dart';
