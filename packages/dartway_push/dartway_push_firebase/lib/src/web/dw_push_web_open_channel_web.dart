import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// A click on a web notification while the tab is already open.
///
/// The service worker handles the click outside Flutter — it has no router in
/// reach, only a URL. When it finds an open tab it focuses it and posts the
/// path here instead of opening a second one; when it does not, it opens the
/// URL itself and the path arrives as an ordinary navigation.
///
/// Returns an unsubscribe function: the listener sits on `serviceWorker`, which
/// outlives any widget, so whoever attached it has to detach it.
void Function() listenWebPushOpen(void Function(String link) onPushOpened) {
  final listener = (web.MessageEvent event) {
    final message = event.data;
    if (message == null || !message.isA<JSObject>()) return;

    final data = message as JSObject;
    final type = data.getProperty<JSString?>('type'.toJS)?.toDart;
    if (type != 'dw-push-open') return;

    final link = data.getProperty<JSString?>('link'.toJS)?.toDart;
    if (link == null || link.isEmpty) return;

    debugPrint('DwPush: the service worker asked to open $link');
    onPushOpened(link);
  }.toJS;

  web.window.navigator.serviceWorker.addEventListener('message', listener);

  return () => web.window.navigator.serviceWorker.removeEventListener(
    'message',
    listener,
  );
}
