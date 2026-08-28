import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../protocol/studio_bridge_message.dart';
import '../../protocol/studio_bridge_protocol.dart';
import '../studio_message_channel.dart';
import '../studio_message_drop.dart';
import '../studio_message_drop_report.dart';

/// True when this page runs inside an iframe (a potential Studio frame).
bool get isEmbeddedInStudioFrame {
  final parent = web.window.parent;
  if (parent == null) return false;
  return !(web.window as JSObject).strictEquals(parent as JSObject).toDart;
}

/// See the origin note on the conditional-export file. [onMessageDropped] is
/// told about every window message this channel refused; the channel behaves
/// exactly the same whether one is installed or not.
StudioMessageChannel? createStudioHostChannel({
  StudioMessageDropObserver? onMessageDropped,
}) {
  if (!isEmbeddedInStudioFrame) return null;
  return _StudioHostWebChannel(onMessageDropped);
}

class _StudioHostWebChannel implements StudioMessageChannel {
  _StudioHostWebChannel(this._onMessageDropped) {
    _jsListener = _onMessageEvent.toJS;
    web.window.addEventListener('message', _jsListener);
  }

  final StudioMessageDropObserver? _onMessageDropped;
  final _controller = StreamController<StudioBridgeMessage>.broadcast();
  late final JSFunction _jsListener;

  /// Studio's origin once the first valid bridge message arrives; targeted
  /// replies go there instead of `*`.
  String? _peerOrigin;

  @override
  Stream<StudioBridgeMessage> get messages => _controller.stream;

  void _onMessageEvent(web.Event event) {
    if (!event.isA<web.MessageEvent>()) {
      _dropped(StudioMessageDropReason.notAMessageEvent);
      return;
    }
    event as web.MessageEvent;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) {
      _dropped(StudioMessageDropReason.nonStringData, origin: event.origin);
      return;
    }
    final payload = (data as JSString).toDart;
    final message = StudioBridgeMessage.tryDecode(payload);
    if (message != null) {
      _peerOrigin = event.origin;
      _controller.add(message);
      return;
    }
    if (_onMessageDropped == null) return;
    // Parsed again only to explain a drop — see the Studio-side channel.
    _dropped(
      StudioMessageDropReason.ofPayload(payload) ??
          StudioMessageDropReason.unknownType,
      origin: event.origin,
      envelopeVersion: StudioBridgeProtocol.envelopeVersionOf(payload),
    );
  }

  void _dropped(
    StudioMessageDropReason reason, {
    String? origin,
    int? envelopeVersion,
  }) {
    if (_onMessageDropped == null) return;
    reportStudioMessageDrop(
      _onMessageDropped,
      StudioMessageDrop(
        reason,
        origin: origin,
        envelopeVersion: envelopeVersion,
      ),
    );
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
