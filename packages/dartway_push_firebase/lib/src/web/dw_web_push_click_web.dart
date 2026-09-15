import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:web/web.dart' as web;

import '../dw_firebase_push.dart';

/// A click the service worker handled while a tab of the app was open: it
/// focused the tab and posted `{type, link, data}` here. Returns the function
/// that stops listening.
void Function() listenWebPushClicks(
  void Function(Map<Object?, Object?> data) onClick,
) {
  final serviceWorker = web.window.navigator.serviceWorker;
  final listener = (web.MessageEvent event) {
    final message = event.data;
    if (message == null || !message.isA<JSObject>()) return;
    final object = message as JSObject;
    final type = object.getProperty<JSAny?>('type'.toJS);
    if (type == null ||
        (type as JSString).toDart != DwFirebasePush.webOpenMessageType) {
      return;
    }
    final data = switch (object.getProperty<JSAny?>('data'.toJS).dartify()) {
      final Map<Object?, Object?> map => {...map},
      _ => <Object?, Object?>{},
    };
    final link = object.getProperty<JSAny?>('link'.toJS);
    if (link != null && link.isA<JSString>()) {
      data[DwPushData.linkKey] = (link as JSString).toDart;
    }
    onClick(data);
  }.toJS;
  serviceWorker.addEventListener('message', listener);
  return () => serviceWorker.removeEventListener('message', listener);
}
