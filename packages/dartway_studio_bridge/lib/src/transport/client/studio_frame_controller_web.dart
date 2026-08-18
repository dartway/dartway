import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '../studio_message_channel.dart';
import 'studio_client_web_channel.dart';
import 'studio_frame_controller.dart';

int _instanceCounter = 0;

StudioFrameController createStudioFrameController({required String appUrl}) =>
    _StudioFrameControllerWeb(appUrl);

class _StudioFrameControllerWeb implements StudioFrameController {
  _StudioFrameControllerWeb(String appUrl)
    : viewType = 'dartway-studio-frame-${_instanceCounter++}' {
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
    _channel = StudioClientWebChannel(_frame, Uri.parse(appUrl).origin);
  }

  late final web.HTMLIFrameElement _frame;
  late final StudioClientWebChannel _channel;

  @override
  final String viewType;

  @override
  StudioMessageChannel get channel => _channel;

  @override
  void dispose() => _channel.dispose();
}
