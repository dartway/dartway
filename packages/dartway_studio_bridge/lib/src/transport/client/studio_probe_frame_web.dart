import 'package:web/web.dart' as web;

import '../studio_message_channel.dart';
import 'studio_client_web_channel.dart';
import 'studio_probe_frame.dart';

StudioProbeFrame openStudioProbeFrame({required String appUrl}) =>
    _StudioProbeFrameWeb(appUrl);

class _StudioProbeFrameWeb implements StudioProbeFrame {
  _StudioProbeFrameWeb(String appUrl) {
    _frame = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = appUrl;
    _frame.style
      ..border = 'none'
      ..width = '1px'
      ..height = '1px';

    // The frame lives in a container of ours, appended straight to the body:
    // the probe owns the element outright, so there is no "has the embedder
    // laid it out yet" to wait on.
    //
    // Hidden, but not by any means that would stop the load. `display: none`
    // and `visibility: hidden` are exactly that — a browser is free to skip
    // fetching a frame it will not paint, and a frame that never loads never
    // answers, which would turn every probe into a timeout. Zero opacity over
    // one pixel, pinned out of the flow and deaf to the pointer, is a frame
    // that loads and runs while being neither seen nor reachable.
    _container = web.document.createElement('div') as web.HTMLDivElement;
    _container.style
      ..position = 'fixed'
      ..left = '0'
      ..top = '0'
      ..width = '1px'
      ..height = '1px'
      ..overflow = 'hidden'
      ..opacity = '0'
      ..pointerEvents = 'none'
      ..zIndex = '-1';
    _container.appendChild(_frame);
    (web.document.body ?? web.document.documentElement!)
        .appendChild(_container);

    _channel = StudioClientWebChannel(_frame, Uri.parse(appUrl).origin);
  }

  late final web.HTMLIFrameElement _frame;
  late final web.HTMLDivElement _container;
  late final StudioClientWebChannel _channel;

  @override
  StudioMessageChannel get channel => _channel;

  @override
  void dispose() {
    _channel.dispose();
    _container.remove();
  }
}
