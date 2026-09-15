import 'package:dartway_core_flutter/dartway_core_flutter.dart';

import 'dw_push_transport_client.dart';

/// A notification the user opened.
final class DwPushOpened {
  const DwPushOpened({required this.source, this.payload, this.link});

  final DwPushOpenSource source;

  /// The typed payload the server sent (`DwPushMessage.data`), decoded by the
  /// app's protocol; `null` when it sent none.
  final DwDataObject? payload;

  /// The in-app path the server sent (`DwPushMessage.link`).
  final String? link;

  /// [payload] when it is a [T].
  T? payloadAs<T extends DwDataObject>() => switch (payload) {
    final T typed => typed,
    _ => null,
  };

  @override
  String toString() =>
      'DwPushOpened(${source.name}, payload: ${payload?.dwTypeName}, '
      'link: $link)';
}

/// A notification that arrived while the app was on screen. Reported, never
/// acted on: taking the user elsewhere because something arrived is the app's
/// decision.
final class DwPushReceived {
  const DwPushReceived({this.title, this.body, this.payload, this.link});

  final String? title;
  final String? body;
  final DwDataObject? payload;
  final String? link;

  T? payloadAs<T extends DwDataObject>() => switch (payload) {
    final T typed => typed,
    _ => null,
  };
}
