import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../protocol/studio_bridge_message.dart';
import '../studio_message_channel.dart';

/// The Studio-side channel to an app in an iframe: `window` message events,
/// filtered down to bridge messages that really came from that frame.
///
/// Shared by everything on this side that owns a frame — the long-lived preview
/// (`StudioFrameController`) and the one-shot probe — so that the filtering is
/// written once. Two copies of it would be two chances to forget the source
/// check, and the one that forgot would accept messages from any page that
/// happens to sit on the app's origin.
class StudioClientWebChannel implements StudioMessageChannel {
  StudioClientWebChannel(this._frame, this._appOrigin) {
    _jsListener = _onMessageEvent.toJS;
    web.window.addEventListener('message', _jsListener);
  }

  final web.HTMLIFrameElement _frame;
  final String _appOrigin;
  final _controller = StreamController<StudioBridgeMessage>.broadcast();
  late final JSFunction _jsListener;

  @override
  Stream<StudioBridgeMessage> get messages => _controller.stream;

  void _onMessageEvent(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;
    event as web.MessageEvent;
    if (event.origin != _appOrigin) return;
    final appWindow = _frame.contentWindow;
    if (appWindow == null ||
        event.source == null ||
        !(event.source as JSObject)
            .strictEquals(appWindow as JSObject)
            .toDart) {
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final message = StudioBridgeMessage.tryDecode((data as JSString).toDart);
    if (message == null) return;
    _controller.add(message);
  }

  @override
  void send(StudioBridgeMessage message) {
    _frame.contentWindow?.postMessage(message.encode().toJS, _appOrigin.toJS);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _jsListener);
    _controller.close();
  }
}
