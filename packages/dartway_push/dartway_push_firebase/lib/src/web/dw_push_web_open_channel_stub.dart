/// Nothing to listen to off the web: the notification click is handled by the
/// platform and arrives through the SDK.
void Function() listenWebPushOpen(void Function(String link) onPushOpened) =>
    () {};
