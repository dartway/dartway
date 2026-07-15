import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:device_frame/device_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';

export 'package:dartway_flutter/dartway_flutter.dart';

part '1_essentials/app_checkbox.dart';
part '1_essentials/app_text_form_field.dart';
part '1_essentials/app_version_label.dart';
part '1_essentials/multi_link_text.dart';
part '2_frequent/app_card.dart';
part '2_frequent/app_rating_stars.dart';
part '2_frequent/phone_text_field.dart';
part '2_frequent/show_app_bottom_sheet_extension.dart';
part '3_special/auth/checkbox_form_field.dart';
part '3_special/auth/pin_code_text_field.dart';
part '3_special/chat/chat_bubble_container.dart';
part '3_special/common/connection_status_indicator.dart';
part 'layout/device_frame_shell.dart';
part 'theme/app_button.dart';
part 'theme/app_context.dart';
part 'theme/app_text.dart';
part 'theme/app_theme.dart';
part 'utils/conditional_parent.dart';
part 'utils/date_labels.dart';
part 'utils/formatters.dart';

DwUiAction wipProgressNotificationCallback = dw.action(
  (context) => dw.notify.success('Not implemented yet'),
);
