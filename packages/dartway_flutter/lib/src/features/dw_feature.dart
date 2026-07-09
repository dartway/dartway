import 'dw_feature_spec.dart';

/// Implemented by a widget that *is* a product feature on a screen. The
/// mounted `DwFeature` widgets of the current screen can be discovered at
/// runtime (see `scanMountedFeatures`) — so the feature set stays tied to the
/// real code.
///
/// A contract, not behavior: the widget only declares its descriptor.
/// ```dart
/// class ScheduleSessionList extends ConsumerWidget implements DwFeature {
///   @override
///   DwFeatureSpec get dwFeature => const DwFeatureSpec(id: 'schedule-list', ...);
/// }
/// ```
abstract interface class DwFeature {
  DwFeatureSpec get dwFeature;
}
