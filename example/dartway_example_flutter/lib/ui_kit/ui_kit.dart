import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:device_frame/device_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter_svg/flutter_svg.dart';

export 'package:dartway_core_flutter/dartway_core_flutter.dart';

part 'assets/app_icon.dart';
part 'assets/app_icon_view.dart';
part '1_essentials/app_checkbox.dart';
part '1_essentials/app_text_form_field.dart';
part '1_essentials/app_version_label.dart';
part '1_essentials/multi_link_text.dart';
part '2_frequent/app_card.dart';
part '2_frequent/app_rating_stars.dart';
part '2_frequent/load_failed_message.dart';
part '2_frequent/phone_text_field.dart';
part '2_frequent/show_app_bottom_sheet_extension.dart';
part '3_special/auth/checkbox_form_field.dart';
part '3_special/auth/pin_code_text_field.dart';
part '3_special/charts/app_bar_chart.dart';
part '3_special/charts/app_chart_value.dart';
part '3_special/charts/app_pie_chart.dart';
part '3_special/charts/app_stat_value.dart';
part '3_special/chat/chat_bubble_container.dart';
part '3_special/chat/chat_composer_frame.dart';
part '3_special/chat/chat_list_marks.dart';
part '3_special/chat/chat_media.dart';
part '3_special/chat/chat_quote_and_pins.dart';
part '3_special/chat/chat_reactions.dart';
part '3_special/common/connection_status_indicator.dart';
part '3_special/media/app_media_control_bar.dart';
part '3_special/media/app_media_error_view.dart';
part '3_special/media/app_media_next_item_card.dart';
part '3_special/media/app_media_player.dart';
part '3_special/media/app_media_timeline.dart';
part '3_special/media/app_mini_player_chrome.dart';
part 'layout/device_frame_shell.dart';
part 'theme/app_button.dart';
part 'theme/app_context.dart';
part 'theme/app_space.dart';
part 'theme/app_text.dart';
part 'theme/app_theme.dart';
part 'utils/app_keyboard_inset.dart';
part 'utils/conditional_parent.dart';
part 'utils/date_labels.dart';
part 'utils/formatters.dart';

/// For links whose destination does not exist yet.
extension AppWipAction on DwFlutterCore {
  /// A getter, not a stored action: an action is bound to the core it was
  /// built on, and a test builds a new core per test.
  DwUiAction<void> get notImplementedYet =>
      action((context) => notify.success('Not implemented yet'));
}
