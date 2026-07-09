// lib/dartway_flutter.dart
// Core app functionality

// Recommended UI packages
export 'package:conditional_parent_widget/conditional_parent_widget.dart';

// Feature declarations: mark a widget as a product feature (DwFeature) and
// discover the mounted ones at runtime — feature catalogs, error-report
// context, analytics; the app's Studio binding maps them onto the bridge.
export 'src/features/dw_feature.dart';
export 'src/features/dw_feature_scanner.dart';
export 'src/features/dw_feature_spec.dart';

// DwApp configuration
export 'src/dw/configs/dw_config.dart';
export 'src/dw/configs/dw_telegram_web_app_config.dart';
export 'src/dw/dw.dart';
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
export 'src/ui_kit/base_widgets/dw_button/dw_button.dart';
export 'src/ui_kit/base_widgets/dw_button/dw_button_style_preset.dart';
export 'src/ui_kit/base_widgets/dw_button/dw_button_style_preset_extension.dart';
export 'src/ui_kit/base_widgets/dw_text.dart';
export 'src/ui_kit/base_widgets/multi_link_text.dart';
export 'src/ui_kit/dialogs/dw_ui_confirmation.dart';
export 'src/ui_kit/layout_widgets/dw_device_frame.dart';
export 'src/ui_kit/layout_widgets/infinite_list_view/domain/dw_infinite_list_view_config.dart';
export 'src/ui_kit/layout_widgets/infinite_list_view/domain/dw_infinite_list_view_grouped_item.dart';
// UI Components
export 'src/ui_kit/layout_widgets/infinite_list_view/infinite_list_view.dart';
export 'src/ui_kit/theme/dw_color_preset.dart';
export 'src/ui_kit/theme/dw_flutter_theme.dart';
export 'src/ui_kit/theme/dw_text_style_preset.dart';
export 'src/utils/dw_async_value_extension.dart';
export 'src/utils/dw_build_async_list_value_extension.dart';
export 'src/utils/dw_build_context_extension.dart';
// Utilities
export 'src/utils/dw_ui_action.dart';
