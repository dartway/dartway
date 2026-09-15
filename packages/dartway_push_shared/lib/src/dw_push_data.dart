import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';

/// What a notification carries for the app besides its text: a typed
/// [payload] and a [link] — the in-app path a tap opens.
///
/// The server writes it into the provider's data map with [toWire], the app
/// reads it back with [fromWire]. Both call this class, so the keys exist
/// once (the lesson of #85: wire keys held on two sides by string tests that
/// could pass while the sides disagreed). The web service worker, which runs
/// outside Dart, is checked against [linkKey] by a test that executes it.
///
/// A provider's data map holds strings only; the payload travels as its
/// wire name and its JSON, and is decoded by the protocol the app speaks — a
/// project's data object, never a map of hand-picked keys.
final class DwPushData {
  const DwPushData({this.payload, this.link});

  /// The data object the app receives, registered in the protocol.
  final DwDataObject? payload;

  /// The in-app path a tap opens (`/news/12`): what the web service worker
  /// navigates to, and what the app routes by when it has no payload.
  final String? link;

  /// The data key of the payload's wire name.
  static const String typeKey = 'dw_type';

  /// The data key of the payload's JSON.
  static const String payloadKey = 'dw_payload';

  /// The data key of [link].
  static const String linkKey = 'dw_link';

  /// Keys of a notification drawn by the app itself, for a transport that
  /// cannot show one with a picture: RuStore ignores an image in its
  /// notification block, so such a message travels as data only and
  /// `dartway_push_rustore` draws it on the device from these.
  static const String titleKey = 'dw_title';
  static const String bodyKey = 'dw_body';
  static const String imageKey = 'dw_image';

  bool get isEmpty => payload == null && link == null;

  /// The provider data map: only the keys that have a value.
  Map<String, String> toWire() => {
    if (payload case final payload?) ...{
      typeKey: payload.dwTypeName,
      payloadKey: jsonEncode(payload.toJson()),
    },
    linkKey: ?link,
  };

  /// Reads a provider data map (other keys are ignored). Throws
  /// [FormatException] when the payload keys are present but not a payload
  /// [protocol] knows — an app older than the server that sent it, or a
  /// message that is not ours.
  static DwPushData fromWire(
    Map<Object?, Object?> data,
    DwWireProtocol protocol,
  ) {
    final type = data[typeKey];
    final encoded = data[payloadKey];
    final link = data[linkKey];
    DwDataObject? payload;
    if (type != null || encoded != null) {
      if (type is! String || encoded is! String) {
        throw FormatException(
          'A push payload needs both "$typeKey" and "$payloadKey" as text',
        );
      }
      final entry = protocol.entryNamed(type);
      if (entry == null || entry.kind != DwWireObjectKind.dataObject) {
        throw FormatException(
          'The push payload "$type" is not a data object of this protocol',
        );
      }
      payload = protocol.decodeNamed(type, jsonDecode(encoded)) as DwDataObject;
    }
    if (link != null && link is! String) {
      throw FormatException('The push link must be text, got $link');
    }
    return DwPushData(
      payload: payload,
      link: (link as String?)?.isEmpty ?? true ? null : link,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DwPushData && other.payload == payload && other.link == link;

  @override
  int get hashCode => Object.hash(payload, link);

  @override
  String toString() => 'DwPushData(payload: $payload, link: $link)';
}
