import 'studio_probe_frame.dart';

/// The Studio client loads an app in an iframe — web only.
StudioProbeFrame openStudioProbeFrame({required String appUrl}) =>
    throw UnsupportedError('StudioProbeFrame is only available in web builds');
