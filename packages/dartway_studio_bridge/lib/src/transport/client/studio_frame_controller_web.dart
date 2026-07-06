import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '../../protocol/studio_bridge_message.dart';
import '../studio_message_channel.dart';
import 'studio_frame_controller.dart';

int _instanceCounter = 0;

StudioFrameController createStudioFrameController({required String appUrl}) =>
    _StudioFrameControllerWeb(appUrl);

class _StudioFrameControllerWeb implements StudioFrameController {
  _StudioFrameControllerWeb(String appUrl)
      : _appOrigin = Uri.parse(appUrl).origin,
        viewType = 'dartway-studio-frame-${_instanceCounter++}' {
    _frame = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = appUrl;
    _frame.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => _frame,
    );
    _channel = _StudioClientWebChannel(_frame, _appOrigin);
  }

  final String _appOrigin;
  late final web.HTMLIFrameElement _frame;
  late final _StudioClientWebChannel _channel;

  @override
  final String viewType;

  @override
  StudioMessageChannel get channel => _channel;

  @override
  void dispose() => _channel.dispose();
}

class _StudioClientWebChannel implements StudioMessageChannel {
  _StudioClientWebChannel(this._frame, this._appOrigin) {
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
    _frame.contentWindow
        ?.postMessage(message.encode().toJS, _appOrigin.toJS);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _jsListener);
    _controller.close();
  }
}
