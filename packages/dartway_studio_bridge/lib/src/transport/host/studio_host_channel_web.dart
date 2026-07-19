import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../protocol/studio_bridge_message.dart';
import '../studio_message_channel.dart';

/// True when this page runs inside an iframe (a potential Studio frame).
bool get isEmbeddedInStudioFrame {
  final parent = web.window.parent;
  if (parent == null) return false;
  return !(web.window as JSObject).strictEquals(parent as JSObject).toDart;
}

/// See the origin note on the conditional-export file.
StudioMessageChannel? createStudioHostChannel() {
  if (!isEmbeddedInStudioFrame) return null;
  return _StudioHostWebChannel();
}

class _StudioHostWebChannel implements StudioMessageChannel {
  _StudioHostWebChannel() {
    _jsListener = _onMessageEvent.toJS;
    web.window.addEventListener('message', _jsListener);
  }

  final _controller = StreamController<StudioBridgeMessage>.broadcast();
  late final JSFunction _jsListener;

  /// Studio's origin once the first valid bridge message arrives; targeted
  /// replies go there instead of `*`.
  String? _peerOrigin;

  @override
  Stream<StudioBridgeMessage> get messages => _controller.stream;

  void _onMessageEvent(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;
    event as web.MessageEvent;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final message = StudioBridgeMessage.tryDecode((data as JSString).toDart);
    if (message == null) return;
    _peerOrigin = event.origin;
    _controller.add(message);
  }

  @override
  void send(StudioBridgeMessage message) {
    final parent = web.window.parent;
    if (parent == null) return;
    final encoded = message.encode().toJS;
    final peer = _peerOrigin;
    parent.postMessage(encoded, (peer ?? '*').toJS);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _jsListener);
    _controller.close();
  }
}
