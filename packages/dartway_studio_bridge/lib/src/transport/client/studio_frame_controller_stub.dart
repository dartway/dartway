import '../studio_message_drop.dart';
import 'studio_frame_controller.dart';

/// The Studio client renders the app in an iframe — web only.
StudioFrameController createStudioFrameController({
  required String appUrl,
  StudioMessageDropObserver? onMessageDropped,
}) => throw UnsupportedError(
  'StudioFrameController is only available in web builds',
);
