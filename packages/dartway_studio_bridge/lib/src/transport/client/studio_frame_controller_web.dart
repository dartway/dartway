import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '../studio_message_channel.dart';
import '../studio_message_drop.dart';
import 'studio_client_web_channel.dart';
import 'studio_frame_controller.dart';

int _instanceCounter = 0;

StudioFrameController createStudioFrameController({
  required String appUrl,
  StudioMessageDropObserver? onMessageDropped,
}) => _StudioFrameControllerWeb(appUrl, onMessageDropped);

class _StudioFrameControllerWeb implements StudioFrameController {
  _StudioFrameControllerWeb(
    String appUrl,
    StudioMessageDropObserver? onMessageDropped,
  ) : viewType = 'dartway-studio-frame-${_instanceCounter++}' {
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
    _channel = StudioClientWebChannel(
      _frame,
      Uri.parse(appUrl).origin,
      onMessageDropped: onMessageDropped,
    );
  }

  late final web.HTMLIFrameElement _frame;
  late final StudioClientWebChannel _channel;
  bool _disposed = false;

  @override
  final String viewType;

  @override
  StudioMessageChannel get channel => _channel;

  @override
  void setInteractive(bool interactive) {
    if (_disposed) return;
    _frame.style.pointerEvents = interactive ? 'auto' : 'none';
  }

  @override
  void dispose() {
    _disposed = true;
    _channel.dispose();
  }
}
