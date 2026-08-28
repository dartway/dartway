import '../studio_message_drop.dart';
import 'studio_probe_frame.dart';

/// The Studio client loads an app in an iframe — web only.
StudioProbeFrame openStudioProbeFrame({
  required String appUrl,
  StudioMessageDropObserver? onMessageDropped,
}) =>
    throw UnsupportedError('StudioProbeFrame is only available in web builds');
