import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../protocol/studio_bridge_message.dart';
import '../studio_message_channel.dart';

/// True when this page runs inside an iframe (a potential Studio frame).
bool get isEmbeddedInStudioFrame {
  final parent = web.window.parent;
  if (parent == null) return false;
  return !(web.window as JSObject).strictEquals(parent as JSObject).toDart;
}

/// See the origin policy on the conditional-export file.
StudioMessageChannel? createStudioHostChannel({
  required List<String> allowedStudioOrigins,
}) {
  if (!isEmbeddedInStudioFrame) return null;
  if (allowedStudioOrigins.isEmpty && kReleaseMode) return null;
  return _StudioHostWebChannel(allowedStudioOrigins);
}

class _StudioHostWebChannel implements StudioMessageChannel {
  _StudioHostWebChannel(this._allowedOrigins) {
    _jsListener = _onMessageEvent.toJS;
    web.window.addEventListener('message', _jsListener);
  }

  final List<String> _allowedOrigins;
  final _controller = StreamController<StudioBridgeMessage>.broadcast();
  late final JSFunction _jsListener;

  /// Studio's origin once the first permitted message arrives; targeted
  /// replies go here.
  String? _peerOrigin;

  @override
  Stream<StudioBridgeMessage> get messages => _controller.stream;

  void _onMessageEvent(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;
    event as web.MessageEvent;
    final origin = event.origin;
    if (_allowedOrigins.isNotEmpty && !_allowedOrigins.contains(origin)) {
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final message = StudioBridgeMessage.tryDecode((data as JSString).toDart);
    if (message == null) return;
    _peerOrigin = origin;
    _controller.add(message);
  }

  @override
  void send(StudioBridgeMessage message) {
    final parent = web.window.parent;
    if (parent == null) return;
    final encoded = message.encode().toJS;
    final peer = _peerOrigin;
    if (peer != null) {
      parent.postMessage(encoded, peer.toJS);
    } else if (_allowedOrigins.isNotEmpty) {
      for (final origin in _allowedOrigins) {
        parent.postMessage(encoded, origin.toJS);
      }
    } else {
      // Debug-only announcement before Studio's origin is known (the message
      // is `appReady`, which carries no payload).
      parent.postMessage(encoded, '*'.toJS);
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _jsListener);
    _controller.close();
  }
}
