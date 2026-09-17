import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The platform an install runs on.
enum DwAnalyticsPlatform { android, ios, web, macos, windows, linux, other }

/// Refusals of the analytics calls.
enum DwAnalyticsRefusal implements DwRefusalCode {
  /// The batch breaks a limit of [DwTrackEvents]: too many events, a name or
  /// a property the store does not take, or a malformed install id. The
  /// field is `events` or `installId`.
  batchInvalid('dw.analyticsBatchInvalid');

  const DwAnalyticsRefusal(this.code);

  @override
  final String code;
}

/// One event as the app recorded it.
final class DwTrackedEvent {
  const DwTrackedEvent({
    required this.name,
    required this.occurredAt,
    required this.sequence,
    this.properties = const {},
  });

  /// [DwAnalyticsEvent.eventName].
  final String name;

  /// When it happened, by the device's clock. The server keeps its own
  /// receipt time beside it: a device clock can be anything.
  final DateTime occurredAt;

  /// This install's running number of the event. A batch sent again — after
  /// a lost answer, after a restart — carries the same numbers, and the
  /// server keeps each once.
  final int sequence;

  /// What distinguishes this occurrence: strings, numbers, booleans. Nothing
  /// nested — a property is a column of a report, not a document.
  final Map<String, Object?> properties;

  static const int maxNameLength = 100;
  static const int maxProperties = 30;
  static const int maxKeyLength = 64;
  static const int maxStringLength = 1000;

  static final RegExp _name = RegExp(r'^[A-Za-z][A-Za-z0-9_.]*$');
  static final RegExp _key = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  /// Why this event cannot be stored, or null when it can.
  String? get problem {
    if (name.length > maxNameLength || !_name.hasMatch(name)) {
      return 'event name "$name" is not letters, digits, _ and . '
          '(at most $maxNameLength)';
    }
    if (sequence < 0) return 'event $name has a negative sequence';
    if (properties.length > maxProperties) {
      return 'event $name has ${properties.length} properties '
          '(at most $maxProperties)';
    }
    for (final MapEntry(:key, :value) in properties.entries) {
      if (key.length > maxKeyLength || !_key.hasMatch(key)) {
        return 'property "$key" of $name is not letters, digits and _ '
            '(at most $maxKeyLength)';
      }
      final fits = switch (value) {
        null || bool() => true,
        num() => value.isFinite,
        String() => value.length <= maxStringLength,
        _ => false,
      };
      if (!fits) {
        return 'property "$key" of $name is not a string (at most '
            '$maxStringLength), a finite number, a boolean or null';
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'occurredAt': DwJsonCodec.encodeDateTime(occurredAt),
    'sequence': sequence,
    if (properties.isNotEmpty) 'properties': properties,
  };

  static DwTrackedEvent fromJson(Map<String, Object?> json) => DwTrackedEvent(
    name: json['name']! as String,
    occurredAt: DwJsonCodec.decodeDateTime(json['occurredAt']),
    sequence: json['sequence']! as int,
    properties:
        (json['properties'] as Map?)?.cast<String, Object?>() ?? const {},
  );

  @override
  bool operator ==(Object other) =>
      other is DwTrackedEvent &&
      other.name == name &&
      other.occurredAt == occurredAt &&
      other.sequence == sequence &&
      _sameProperties(other.properties, properties);

  static bool _sameProperties(Map<String, Object?> a, Map<String, Object?> b) =>
      a.length == b.length &&
      a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);

  @override
  int get hashCode =>
      Object.hash(name, occurredAt, sequence, properties.length);

  @override
  String toString() => 'DwTrackedEvent($name #$sequence)';
}

/// Stores a batch of events recorded by one install of the app.
///
/// Open to a signed-out app: what a person does before signing in is the
/// part a funnel is about. The account is never a field — the server takes
/// the caller's, so events are attributed to whoever the call was signed in
/// as. The install id is the app's own, kept on the device, and ties the
/// events before a sign-in to those after it.
final class DwTrackEvents extends DwActionCommand<void>
    implements DwSelfValidating {
  const DwTrackEvents({
    required this.installId,
    required this.platform,
    required this.appVersion,
    required this.events,
  });

  /// Events one call may carry; the app sends more in several.
  static const int maxEvents = 100;

  static final RegExp _installId = RegExp(r'^[A-Za-z0-9-]{16,64}$');

  final String installId;
  final DwAnalyticsPlatform platform;

  /// The build that recorded the events, `<semver>+<build>`.
  final String appVersion;
  final List<DwTrackedEvent> events;

  @override
  List<DwCallRefusal> validate() => [
    if (!_installId.hasMatch(installId))
      DwCallRefusal(DwAnalyticsRefusal.batchInvalid, field: 'installId'),
    if (events.isEmpty ||
        events.length > maxEvents ||
        appVersion.length > 64 ||
        events.any((event) => event.problem != null))
      DwCallRefusal(DwAnalyticsRefusal.batchInvalid, field: 'events'),
  ];

  @override
  String get dwTypeName => 'DwTrackEvents';

  @override
  Map<String, Object?> toJson() => {
    'installId': installId,
    'platform': platform.name,
    'appVersion': appVersion,
    'events': [for (final event in events) event.toJson()],
  };

  static DwTrackEvents fromJson(Map<String, Object?> json) => DwTrackEvents(
    installId: json['installId']! as String,
    platform: DwJsonCodec.decodeEnum(
      json['platform'],
      DwAnalyticsPlatform.values,
    ),
    appVersion: json['appVersion']! as String,
    events: DwJsonCodec.decodeList(
      json['events'],
      (item) => DwTrackedEvent.fromJson((item! as Map).cast<String, Object?>()),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is DwTrackEvents &&
      other.installId == installId &&
      other.platform == platform &&
      other.appVersion == appVersion &&
      other.events.length == events.length &&
      [
        for (var i = 0; i < events.length; i++) other.events[i] == events[i],
      ].every((same) => same);

  @override
  int get hashCode =>
      Object.hash(installId, platform, appVersion, events.length);

  @override
  String toString() =>
      'DwTrackEvents($installId, ${platform.name}, ${events.length} events)';
}

/// The analytics calls, for the project's protocol:
///
/// ```dart
/// final appProtocol = DwWireProtocol(
///   dwAnalyticsProtocolEntries,
///   include: shopProtocol,
/// );
/// ```
const List<DwProtocolEntry> dwAnalyticsProtocolEntries = [
  DwProtocolEntry<DwTrackEvents>('DwTrackEvents', DwTrackEvents.fromJson),
];
