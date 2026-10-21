import 'dart:async';
import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../server/dw_server_clock.dart';
import '../server/dw_server_settings.dart';

/// Holds what a call answers to the bounds of `DwServerSettings`: a whole
/// list to its request's `maxItems`, and any response to
/// `largeResponseBytes` (dartway/dartway#644).
///
/// A list that grew past its bound is never cut short — a shorter list is a
/// wrong answer nobody notices. With `strictBounds` the call fails, naming the
/// request and the count; without it the whole list is served and a warning
/// says so, once per request per `boundWarningInterval`, read on the server's
/// clock.
@internal
final class DwBoundWatch {
  DwBoundWatch({
    required DwServerSettings settings,
    required this.log,
    required this.clock,
    bool? strict,
  }) : strict = strict ?? settings.strictBounds,
       largeResponseBytes = settings.largeResponseBytes,
       interval = settings.boundWarningInterval;

  static final Object _zoneKey = Object();

  /// Runs a handler with this server's bound policy, isolated per async call.
  R run<R>(R Function() body) => runZoned(body, zoneValues: {_zoneKey: this});

  static DwBoundWatch get current =>
      Zone.current[_zoneKey] as DwBoundWatch? ??
      (throw StateError('readWhole must run inside a request handler'));

  /// Rejects the bounded probe before an expensive unbounded read in strict mode.
  void checkProbe(DwListRequest<DwDataObject> request, int count) {
    if (strict && count > request.maxItems) {
      _overflow(request.dwTypeName, count, request.maxItems);
    }
  }

  Never _overflow(String name, int count, int bound) => throw StateError(
    '$name answered $count items, past its bound of $bound (maxItems): $_fix',
  );

  static const _fix =
      'page it (DwPageRequest, DwTableRequest, DwWindowRequest), or raise its '
      'maxItems with the reason in its doc comment; use request.readWhole '
      'for a whole list';

  final DwServerLogger log;
  final DwServerClock clock;

  /// Whether a list past its bound fails the call.
  final bool strict;
  final int largeResponseBytes;
  final Duration interval;

  /// Request name → when its bound breach was last logged.
  final Map<String, DateTime> _listWarned = {};

  /// Call name → when its large response was last logged.
  final Map<String, DateTime> _sizeWarned = {};

  static final JsonUtf8Encoder _jsonUtf8 = JsonUtf8Encoder();

  /// Holds [encoded], the answer of [request] named [name], to the request's
  /// `maxItems`. Throws [StateError] past it when [strict].
  void checkList(
    String name,
    DwListRequest<DwDataObject> request,
    List<Object?> encoded,
  ) {
    final count = encoded.length;
    final bound = request.maxItems;
    if (count <= bound) return;
    if (strict) _overflow(name, count, bound);
    if (!_due(_listWarned, name)) return;
    final bytes = _jsonUtf8.convert(encoded).length;
    log.warning(
      '$name answered $count items, past its bound of $bound (maxItems), '
      '$bytes bytes; served whole: $_fix',
    );
  }

  /// Logs a response of [bytes] to the call named [name] when it is above
  /// `largeResponseBytes`.
  void checkSize(String name, int bytes) {
    if (bytes <= largeResponseBytes || !_due(_sizeWarned, name)) return;
    log.warning(
      '$name answered $bytes bytes, above $largeResponseBytes '
      '(largeResponseBytes): page the read, or narrow what it carries',
    );
  }

  /// Whether [name] may be logged again now, recording that it is.
  bool _due(Map<String, DateTime> warned, String name) {
    final now = clock.now();
    final last = warned[name];
    if (last != null && now.difference(last) < interval) return false;
    warned[name] = now;
    return true;
  }
}
