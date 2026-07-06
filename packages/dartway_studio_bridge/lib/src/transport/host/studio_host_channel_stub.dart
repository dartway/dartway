import '../studio_message_channel.dart';

/// Non-web platforms are never embedded in a Studio frame.
bool get isEmbeddedInStudioFrame => false;

/// No transport exists outside the web; the bridge host stays dormant.
StudioMessageChannel? createStudioHostChannel({
  required List<String> allowedStudioOrigins,
}) =>
    null;
