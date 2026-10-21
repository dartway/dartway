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
    final fix =
        'page it (DwPageRequest, DwTableRequest, DwWindowRequest), bound the '
        'read with `limit: request.fetchLimit`, or raise its maxItems with the '
        'reason in its doc comment';
    if (strict) {
      throw StateError(
        '$name answered $count items, past its bound of $bound (maxItems): '
        '$fix',
      );
    }
    if (!_due(_listWarned, name)) return;
    final bytes = _jsonUtf8.convert(encoded).length;
    log.warning(
      '$name answered $count items, past its bound of $bound (maxItems), '
      '$bytes bytes; served whole: $fix',
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
