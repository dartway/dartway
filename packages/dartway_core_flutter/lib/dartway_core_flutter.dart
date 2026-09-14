// lib/dartway_core_flutter.dart
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
// lib/src is grouped into: data (DwFlutterCore and the Riverpod bindings over the
// client), core (the ambient dw + config + plugins), bootstrap (app runner), ui
// (actions, async_ui, notifications, confirmation) and diagnostics (error
// reporting, feature declarations).

// The family re-exports what a project imports directly (D-032): the shared
// contract (DTO kinds, results, refusals, channels), the client, and the
// router. An app imports this package and nothing else of ours, so its
// pubspec names one framework package whose version moves the rest.
export 'package:dartway_client/dartway_client.dart';
export 'package:dartway_core_shared/dartway_core_shared.dart';
export 'package:dartway_router/dartway_router.dart';

// data: DwFlutterCore — the toolbox plus the client and its Riverpod bindings
// (`dw.request`, `dw.pages`, `dw.table`, `dw.window`, `dw.command`,
// `dw.accountId`, `dw.liveStatus`), and uploads (`dw.files`, `dw.uploader()`).
export 'src/data/dw_flutter_core.dart';
export 'src/data/dw_request_notifiers.dart'
    show
        DwPagesNotifier,
        DwPagesProvider,
        DwRequestNotifier,
        DwRequestProvider,
        DwStreamValueNotifier,
        DwTableNotifier,
        DwTableProvider,
        DwValueProvider,
        DwWindowNotifier,
        DwWindowProvider;
export 'src/data/dw_upload_notifier.dart';

// core: the ambient app root, its config, and the plugin registry
// (`dw.plugins.<name>`).
export 'src/core/dw_flutter.dart';
export 'src/core/logic/dw_config.dart';
export 'src/core/logic/dw_key_value_store.dart';
export 'src/core/logic/dw_plugin.dart';

// bootstrap: ProviderScope, native splash, ordered initializers, the global
// error pipeline.
export 'src/bootstrap/dw_app_runner.dart';
export 'src/bootstrap/logic/dw_app_loading_options.dart';
export 'src/bootstrap/widgets/dw_app_bootstrapper.dart';

// ui/actions: the policy (DwUiAction, built via `dw.action`) and the
// widget-agnostic guard that runs it.
export 'src/ui/actions/dw_ui_action.dart';
export 'src/ui/actions/widgets/dw_action_builder.dart';

// ui/window_list: the chat-style list over `dw.window` — newest at the
// bottom, not reversed, grown both ways without moving what is on screen.
export 'src/ui/window_list/dw_window_list_view.dart'
    show
        DwWindowListController,
        DwWindowListEdge,
        DwWindowListItem,
        DwWindowListView;

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
