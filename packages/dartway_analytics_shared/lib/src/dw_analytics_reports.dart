import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dw_list_equality.dart';
import 'dw_track_events.dart';

/// What a report counts.
enum DwAnalyticsMetric {
  /// Events.
  events,

  /// Distinct signed-in accounts that sent the events: people. Events sent
  /// signed out count for no account.
  accounts,

  /// Distinct installs that sent the events: devices, signed in or not.
  /// Events the server recorded have no install and count for none.
  installs,
}

/// A time bucket of a report broken down by time, in the period's local
/// calendar: a day from midnight, a week from Monday, a month from the 1st.
enum DwAnalyticsTimeBucket { day, week, month }

/// A condition on one property: the events whose [property] reads as [value].
///
/// A property is compared as the text of its JSON value — `'3'` matches the
/// number 3 and the string "3", `'true'` the boolean — so a value typed into
/// a form finds what the app sent whatever its type. An event without the
/// property matches no filter on it.
final class DwAnalyticsFilter {
  const DwAnalyticsFilter({required this.property, required this.value});

  final String property;
  final String value;

  Map<String, Object?> toJson() => {'property': property, 'value': value};

  static DwAnalyticsFilter fromJson(Map<String, Object?> json) =>
      DwAnalyticsFilter(
        property: json['property']! as String,
        value: json['value']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsFilter &&
      other.property == property &&
      other.value == value;

  @override
  int get hashCode => Object.hash(property, value);

  @override
  String toString() => '$property = $value';
}

/// How a report splits its total: not at all, by time, or by the values of a
/// property.
final class DwAnalyticsBreakdown {
  /// The total alone.
  const DwAnalyticsBreakdown.none() : bucket = null, property = null, top = 0;

  /// One point per [bucket] of the period, empty buckets included as zero.
  const DwAnalyticsBreakdown.byTime(DwAnalyticsTimeBucket this.bucket)
    : property = null,
      top = 0;

  /// One point per value of [property] — the [top] largest, and the rest
  /// together as the report's `other`.
  const DwAnalyticsBreakdown.byProperty(String this.property, {this.top = 5})
    : bucket = null;

  /// The bucket of a breakdown by time; `null` otherwise.
  final DwAnalyticsTimeBucket? bucket;

  /// The property of a breakdown by property; `null` otherwise.
  final String? property;

  /// How many values of [property] get a point of their own.
  final int top;

  /// The most values a breakdown by property shows apart.
  static const int maxTop = 20;

  bool get isNone => bucket == null && property == null;

  Map<String, Object?> toJson() => {
    if (bucket case final bucket?) 'bucket': bucket.name,
    if (property case final property?) ...{'property': property, 'top': top},
  };

  static DwAnalyticsBreakdown fromJson(Map<String, Object?> json) {
    if (json['property'] case final String property) {
      return DwAnalyticsBreakdown.byProperty(
        property,
        top: json['top']! as int,
      );
    }
    if (json['bucket'] case final Object bucket) {
      return DwAnalyticsBreakdown.byTime(
        DwJsonCodec.decodeEnum(bucket, DwAnalyticsTimeBucket.values),
      );
    }
    return const DwAnalyticsBreakdown.none();
  }

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsBreakdown &&
      other.bucket == bucket &&
      other.property == property &&
      other.top == top;

  @override
  int get hashCode => Object.hash(bucket, property, top);

  @override
  String toString() => switch ((bucket, property)) {
    (final bucket?, _) => 'by ${bucket.name}',
    (_, final property?) => 'by $property (top $top)',
    _ => 'no breakdown',
  };
}

/// What a report counts, without the period: the part of a dashboard widget
/// that stays when the period on top of the dashboard changes.
final class DwAnalyticsReportSpec {
  const DwAnalyticsReportSpec({
    this.eventName,
    this.metric = DwAnalyticsMetric.events,
    this.filters = const [],
    this.breakdown = const DwAnalyticsBreakdown.none(),
  });

  /// The event counted (`DwAnalyticsEvent.eventName`); `null` counts every
  /// event — "active installs" is installs over any event.
  final String? eventName;

  final DwAnalyticsMetric metric;

  /// Conditions every counted event meets, together (AND).
  final List<DwAnalyticsFilter> filters;

  final DwAnalyticsBreakdown breakdown;

  static const int maxFilters = 5;

  static final RegExp _eventName = RegExp(r'^[A-Za-z][A-Za-z0-9_.]*$');
  static final RegExp _propertyKey = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  static bool _isKey(String key) =>
      key.length <= DwTrackedEvent.maxKeyLength && _propertyKey.hasMatch(key);

  /// Why this spec cannot be reported, or null when it can. Names and keys
  /// follow the rules events are stored by: a spec naming what cannot exist
  /// is a mistake, not an empty report.
  String? get problem {
    if (eventName case final name?
        when name.length > DwTrackedEvent.maxNameLength ||
            !_eventName.hasMatch(name)) {
      return 'event name "$name" is not letters, digits, _ and .';
    }
    if (filters.length > maxFilters) {
      return '${filters.length} filters (at most $maxFilters)';
    }
    for (final filter in filters) {
      if (!_isKey(filter.property)) {
        return 'filter property "${filter.property}" is not letters, digits '
            'and _';
      }
      if (filter.value.length > DwTrackedEvent.maxStringLength) {
        return 'filter value of "${filter.property}" is longer than '
            '${DwTrackedEvent.maxStringLength}';
      }
    }
    if (breakdown.property case final property?) {
      if (!_isKey(property)) {
        return 'breakdown property "$property" is not letters, digits and _';
      }
      if (breakdown.top < 1 || breakdown.top > DwAnalyticsBreakdown.maxTop) {
        return 'breakdown top ${breakdown.top} is not 1 to '
            '${DwAnalyticsBreakdown.maxTop}';
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'eventName': ?eventName,
    'metric': metric.name,
    if (filters.isNotEmpty) 'filters': [for (final f in filters) f.toJson()],
    if (!breakdown.isNone) 'breakdown': breakdown.toJson(),
  };

  static DwAnalyticsReportSpec fromJson(Map<String, Object?> json) =>
      DwAnalyticsReportSpec(
        eventName: json['eventName'] as String?,
        metric: DwJsonCodec.decodeEnum(
          json['metric'],
          DwAnalyticsMetric.values,
        ),
        filters: json['filters'] == null
            ? const []
            : DwJsonCodec.decodeList(
                json['filters'],
                (item) => DwAnalyticsFilter.fromJson(
                  (item! as Map).cast<String, Object?>(),
                ),
              ),
        breakdown: json['breakdown'] == null
            ? const DwAnalyticsBreakdown.none()
            : DwAnalyticsBreakdown.fromJson(
                (json['breakdown']! as Map).cast<String, Object?>(),
              ),
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsReportSpec &&
      other.eventName == eventName &&
      other.metric == metric &&
      other.breakdown == breakdown &&
      sameList(other.filters, filters);

  @override
  int get hashCode =>
      Object.hash(eventName, metric, breakdown, Object.hashAll(filters));

  @override
  String toString() =>
      'DwAnalyticsReportSpec(${metric.name} of ${eventName ?? 'every event'}'
      '${filters.isEmpty ? '' : ' where ${filters.join(' and ')}'}, '
      '$breakdown)';
}

/// The time a report covers: from [from] (inclusive) to [to] (exclusive),
/// bucketed in the calendar [utcOffsetMinutes] east of UTC.
///
/// The offset is the viewer's, fixed for the whole period — a day bucket is
/// the viewer's day. It does not follow a daylight-saving change inside the
/// period.
final class DwAnalyticsPeriod {
  const DwAnalyticsPeriod({
    required this.from,
    required this.to,
    this.utcOffsetMinutes = 0,
  });

  /// The local calendar days [first] to [last], both included, in this
  /// device's time zone as of [first] — what a date range picker returns.
  factory DwAnalyticsPeriod.localDays(DateTime first, DateTime last) {
    final start = DateTime(first.year, first.month, first.day);
    final end = DateTime(last.year, last.month, last.day + 1);
    return DwAnalyticsPeriod(
      from: start.toUtc(),
      to: end.toUtc(),
      utcOffsetMinutes: start.timeZoneOffset.inMinutes,
    );
  }

  final DateTime from;
  final DateTime to;
  final int utcOffsetMinutes;

  /// The period of the same length just before this one: what a change is
  /// measured against.
  DwAnalyticsPeriod get previous => DwAnalyticsPeriod(
    from: from.subtract(to.difference(from)),
    to: from,
    utcOffsetMinutes: utcOffsetMinutes,
  );

  /// The longest period a report covers: longer is a query nobody waits for.
  static const Duration maxLength = Duration(days: 3660);

  /// Why this period cannot be reported, or null when it can.
  String? get problem {
    if (!from.isBefore(to)) return 'the period ends before it starts';
    if (to.difference(from) > maxLength) {
      return 'the period is longer than ${maxLength.inDays} days';
    }
    if (utcOffsetMinutes < -12 * 60 || utcOffsetMinutes > 14 * 60) {
      return 'UTC offset $utcOffsetMinutes minutes is not a time zone';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'from': DwJsonCodec.encodeDateTime(from),
    'to': DwJsonCodec.encodeDateTime(to),
    if (utcOffsetMinutes != 0) 'utcOffsetMinutes': utcOffsetMinutes,
  };

  static DwAnalyticsPeriod fromJson(Map<String, Object?> json) =>
      DwAnalyticsPeriod(
        from: DwJsonCodec.decodeDateTime(json['from']),
        to: DwJsonCodec.decodeDateTime(json['to']),
        utcOffsetMinutes: json['utcOffsetMinutes'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsPeriod &&
      other.from == from &&
      other.to == to &&
      other.utcOffsetMinutes == utcOffsetMinutes;

  @override
  int get hashCode => Object.hash(from, to, utcOffsetMinutes);

  @override
  String toString() =>
      'DwAnalyticsPeriod(${from.toIso8601String()} – ${to.toIso8601String()}'
      '${utcOffsetMinutes == 0 ? '' : ', UTC${utcOffsetMinutes > 0 ? '+' : ''}'
                '$utcOffsetMinutes min'})';
}

/// One value of a report's breakdown.
final class DwAnalyticsPoint {
  const DwAnalyticsPoint({required this.label, required this.value});

  /// By time: the bucket's first day, `YYYY-MM-DD` in the period's calendar.
  /// By property: the property's value as text; `null` for the events that
  /// do not carry the property (or carry `null`).
  final String? label;

  final int value;

  Map<String, Object?> toJson() => {'label': label, 'value': value};

  static DwAnalyticsPoint fromJson(Map<String, Object?> json) =>
      DwAnalyticsPoint(
        label: json['label'] as String?,
        value: json['value']! as int,
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsPoint && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => '$label: $value';
}

/// A report: the [total] over the period, and the [points] of its breakdown.
///
/// For [DwAnalyticsMetric.accounts] and [DwAnalyticsMetric.installs] the
/// total counts each account or install once over the whole period, so it is
/// not the sum of the points: a person active on three days is one in the
/// total and one on each of the days.
final class DwAnalyticsReport extends DwDataObject {
  const DwAnalyticsReport({
    required this.total,
    this.points = const [],
    this.other,
  });

  /// A report is an answer to its request, never an object on a channel: its
  /// identity is fixed.
  @override
  String get id => 'analytics-report';

  final int total;

  /// By time: every bucket of the period, oldest first. By property: the
  /// largest values, largest first. Empty without a breakdown.
  final List<DwAnalyticsPoint> points;

  /// By property, when more values exist than the breakdown's `top`: the
  /// count over all the others together. `null` otherwise.
  final int? other;

  @override
  String get dwTypeName => 'DwAnalyticsReport';

  @override
  Map<String, Object?> toJson() => {
    'total': total,
    if (points.isNotEmpty) 'points': [for (final p in points) p.toJson()],
    'other': ?other,
  };

  static DwAnalyticsReport fromJson(Map<String, Object?> json) =>
      DwAnalyticsReport(
        total: json['total']! as int,
        points: json['points'] == null
            ? const []
            : DwJsonCodec.decodeList(
                json['points'],
                (item) => DwAnalyticsPoint.fromJson(
                  (item! as Map).cast<String, Object?>(),
                ),
              ),
        other: json['other'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsReport &&
      other.total == total &&
      other.other == this.other &&
      sameList(other.points, points);

  @override
  int get hashCode => Object.hash(total, other, Object.hashAll(points));

  @override
  String toString() =>
      'DwAnalyticsReport($total, ${points.length} points'
      '${other == null ? '' : ', other $other'})';
}

/// Counts [spec] over [period]. Guarded by the module's `readAccess`.
final class DwGetAnalyticsReport extends DwSingleRequest<DwAnalyticsReport>
    implements DwSelfValidating {
  const DwGetAnalyticsReport({required this.spec, required this.period});

  final DwAnalyticsReportSpec spec;
  final DwAnalyticsPeriod period;

  /// The most time buckets one report returns.
  static const int maxBuckets = 400;

  @override
  List<DwCallRefusal> validate() => [
    if (spec.problem != null)
      DwCallRefusal(DwAnalyticsRefusal.reportInvalid, field: 'spec'),
    if (period.problem != null || _bucketsExceeded)
      DwCallRefusal(DwAnalyticsRefusal.reportInvalid, field: 'period'),
  ];

  /// An upper bound of the buckets, so the check needs no calendar.
  bool get _bucketsExceeded {
    final days = period.to.difference(period.from).inHours / 24;
    final buckets = switch (spec.breakdown.bucket) {
      null => 0,
      DwAnalyticsTimeBucket.day => days + 2,
      DwAnalyticsTimeBucket.week => days / 7 + 2,
      DwAnalyticsTimeBucket.month => days / 28 + 2,
    };
    return buckets > maxBuckets;
  }

  @override
  String get dwTypeName => 'DwGetAnalyticsReport';

  @override
  Map<String, Object?> toJson() => {
    'spec': spec.toJson(),
    'period': period.toJson(),
  };

  static DwGetAnalyticsReport fromJson(Map<String, Object?> json) =>
      DwGetAnalyticsReport(
        spec: DwAnalyticsReportSpec.fromJson(
          (json['spec']! as Map).cast<String, Object?>(),
        ),
        period: DwAnalyticsPeriod.fromJson(
          (json['period']! as Map).cast<String, Object?>(),
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is DwGetAnalyticsReport &&
      other.spec == spec &&
      other.period == period;

  @override
  int get hashCode => Object.hash(spec, period);

  @override
  String toString() => 'DwGetAnalyticsReport($spec, $period)';
}

/// One event name seen in a period, and the property keys it carried.
final class DwAnalyticsCatalogEvent {
  const DwAnalyticsCatalogEvent({
    required this.name,
    required this.count,
    this.propertyKeys = const [],
  });

  final String name;

  /// How many times it was recorded in the period.
  final int count;

  /// Every key any of its events carried, sorted.
  final List<String> propertyKeys;

  Map<String, Object?> toJson() => {
    'name': name,
    'count': count,
    if (propertyKeys.isNotEmpty) 'propertyKeys': propertyKeys,
  };

  static DwAnalyticsCatalogEvent fromJson(Map<String, Object?> json) =>
      DwAnalyticsCatalogEvent(
        name: json['name']! as String,
        count: json['count']! as int,
        propertyKeys:
            (json['propertyKeys'] as List?)?.cast<String>() ?? const [],
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsCatalogEvent &&
      other.name == name &&
      other.count == count &&
      sameList(other.propertyKeys, propertyKeys);

  @override
  int get hashCode => Object.hash(name, count, Object.hashAll(propertyKeys));

  @override
  String toString() => '$name ×$count $propertyKeys';
}

/// What was recorded in a period: the choices a report builder offers
/// instead of free text.
final class DwAnalyticsCatalog extends DwDataObject {
  const DwAnalyticsCatalog({this.events = const []});

  /// An answer to its request only: its identity is fixed.
  @override
  String get id => 'analytics-catalog';

  /// By name.
  final List<DwAnalyticsCatalogEvent> events;

  @override
  String get dwTypeName => 'DwAnalyticsCatalog';

  @override
  Map<String, Object?> toJson() => {
    if (events.isNotEmpty) 'events': [for (final e in events) e.toJson()],
  };

  static DwAnalyticsCatalog fromJson(Map<String, Object?> json) =>
      DwAnalyticsCatalog(
        events: json['events'] == null
            ? const []
            : DwJsonCodec.decodeList(
                json['events'],
                (item) => DwAnalyticsCatalogEvent.fromJson(
                  (item! as Map).cast<String, Object?>(),
                ),
              ),
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsCatalog && sameList(other.events, events);

  @override
  int get hashCode => Object.hashAll(events);

  @override
  String toString() => 'DwAnalyticsCatalog(${events.length} events)';
}

/// The event names and property keys recorded in [period]. Guarded by the
/// module's `readAccess`.
final class DwGetAnalyticsCatalog extends DwSingleRequest<DwAnalyticsCatalog>
    implements DwSelfValidating {
  const DwGetAnalyticsCatalog({required this.period});

  final DwAnalyticsPeriod period;

  @override
  List<DwCallRefusal> validate() => [
    if (period.problem != null)
      DwCallRefusal(DwAnalyticsRefusal.reportInvalid, field: 'period'),
  ];

  @override
  String get dwTypeName => 'DwGetAnalyticsCatalog';

  @override
  Map<String, Object?> toJson() => {'period': period.toJson()};

  static DwGetAnalyticsCatalog fromJson(Map<String, Object?> json) =>
      DwGetAnalyticsCatalog(
        period: DwAnalyticsPeriod.fromJson(
          (json['period']! as Map).cast<String, Object?>(),
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is DwGetAnalyticsCatalog && other.period == period;

  @override
  int get hashCode => period.hashCode;

  @override
  String toString() => 'DwGetAnalyticsCatalog($period)';
}
