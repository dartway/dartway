import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../protocol/studio_bridge_message.dart';
import '../../protocol/studio_bridge_protocol.dart';
import '../studio_message_channel.dart';
import '../studio_message_drop.dart';
import '../studio_message_drop_report.dart';

/// The Studio-side channel to an app in an iframe: `window` message events,
/// filtered down to bridge messages that really came from that frame.
///
/// Shared by everything on this side that owns a frame — the long-lived preview
/// (`StudioFrameController`) and the one-shot probe — so that the filtering is
/// written once. Two copies of it would be two chances to forget the source
/// check, and the one that forgot would accept messages from any page that
/// happens to sit on the app's origin.
///
/// Every one of those filtering steps is a message that silently never arrives.
/// [onMessageDropped] is how an embedder sees them; the channel behaves exactly
/// the same whether one is installed or not.
class StudioClientWebChannel implements StudioMessageChannel {
  StudioClientWebChannel(
    this._frame,
    this._appOrigin, {
    this.onMessageDropped,
  }) {
    _jsListener = _onMessageEvent.toJS;
    web.window.addEventListener('message', _jsListener);
  }

  final web.HTMLIFrameElement _frame;
  final String _appOrigin;

  /// Told about each window message this channel refused. Diagnostics only.
  final StudioMessageDropObserver? onMessageDropped;

  final _controller = StreamController<StudioBridgeMessage>.broadcast();
  late final JSFunction _jsListener;

  @override
  Stream<StudioBridgeMessage> get messages => _controller.stream;

  void _onMessageEvent(web.Event event) {
    if (!event.isA<web.MessageEvent>()) {
      _dropped(StudioMessageDropReason.notAMessageEvent);
      return;
    }
    event as web.MessageEvent;
    if (event.origin != _appOrigin) {
      _dropped(StudioMessageDropReason.foreignOrigin, origin: event.origin);
      return;
    }
    final appWindow = _frame.contentWindow;
    if (appWindow == null ||
        event.source == null ||
        !(event.source as JSObject)
            .strictEquals(appWindow as JSObject)
            .toDart) {
      _dropped(StudioMessageDropReason.foreignSource, origin: event.origin);
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSString>()) {
      _dropped(StudioMessageDropReason.nonStringData, origin: event.origin);
      return;
    }
    final payload = (data as JSString).toDart;
    final message = StudioBridgeMessage.tryDecode(payload);
    if (message != null) {
      _controller.add(message);
      return;
    }
    if (onMessageDropped == null) return;
    // The payload is parsed again only here, to explain a drop — never on the
    // delivered path, and never at all when nobody is watching. `ofPayload`
    // returns null only for a payload that decodes, and this one did not.
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
    if (onMessageDropped == null) return;
    reportStudioMessageDrop(
      onMessageDropped,
      StudioMessageDrop(
        reason,
        origin: origin,
        envelopeVersion: envelopeVersion,
      ),
    );
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
