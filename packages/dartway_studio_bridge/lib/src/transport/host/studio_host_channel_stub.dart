import '../studio_message_channel.dart';
import '../studio_message_drop.dart';

/// Non-web platforms are never embedded in a Studio frame.
bool get isEmbeddedInStudioFrame => false;

/// No transport exists outside the web; the bridge host stays dormant, so
/// there is nothing to drop and [onMessageDropped] is never called.
StudioMessageChannel? createStudioHostChannel({
  StudioMessageDropObserver? onMessageDropped,
}) => null;
