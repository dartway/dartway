import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';

/// Bridges the Flutter error pipeline to the alert schema: the captured
/// app-state snapshot becomes the context block of the Telegram alert.
extension DwErrorReportAlertMapping on DwErrorReport {
  DwAlertContext toAlertContext({String? userLabel}) => DwAlertContext(
        platform: context.platform,
        appVersion: context.appVersion,
        userLabel: userLabel,
        route: context.route,
        features: context.featureIds,
        actionLabel: actionLabel,
        failedCall: failedCall,
        extra: context.entries,
      );
}
