import '../dto/dw_server_call.dart';
import 'dw_http.dart';

/// Which rows of a window a call reads.
enum DwWindowDirection {
  /// Around an anchor, or the newest rows without one.
  around,

  /// Older than a cursor.
  older,

  /// Newer than a cursor.
  newer,
}

/// The page parameters of a call: the query string of `POST /dw/<name>`.
///
/// Only the paginated kinds with a constant page size take one — a
/// [DwPageRequest] an offset, a [DwWindowRequest] a direction — because their
/// position is not part of the request's key: page 2 of a feed is the same
/// state as page 1, grown. A table's page is a field of the request (its key)
/// and travels in the body; the other kinds take no query at all.
///
/// Built by the client, read back by the server with [parse]; one codec, so
/// the two sides cannot disagree about a parameter.
sealed class DwPageQuery {
  const DwPageQuery({this.pageSize})
    : assert(pageSize == null || pageSize > 0, 'pageSize must be positive');

  /// Rows asked for; `null` asks for the request's `pageSize`. The server
  /// serves at most the request's `maxPageSize`.
  final int? pageSize;

  /// The query parameters; empty when everything is the default.
  Map<String, String> toQuery();

  /// Reads the query of a call to [request]. Returns `null` for the kinds that
  /// take no query (which must then be empty), and throws [FormatException]
  /// for a parameter the kind does not define or a value it cannot take —
  /// a malformed call.
  static DwPageQuery? parse(
    DwRequest<Object?> request,
    Map<String, String> query,
  ) => switch (request) {
    DwPageRequest() => DwOffsetQuery._parse(query),
    DwWindowRequest() => DwWindowQuery._parse(query),
    DwSingleRequest() ||
    DwMaybeRequest() ||
    DwListRequest() ||
    DwTableRequest() =>
      query.isEmpty
          ? null
          : throw FormatException(
              '${request.dwTypeName} takes no query parameters, got '
              '${query.keys.join(', ')}',
            ),
  };

  static int? _readPageSize(Map<String, String> query) {
    final raw = query[DwHttp.pageSizeParameter];
    if (raw == null) return null;
    final value = _readCount(raw, DwHttp.pageSizeParameter);
    if (value < 1) {
      throw FormatException('pageSize must be at least 1', raw);
    }
    return value;
  }

  /// A non-negative integer in its canonical spelling: `07` or `+7` is not a
  /// count a client of this codec writes.
  static int _readCount(String raw, String name) {
    final value = int.tryParse(raw);
    if (value == null || value < 0 || '$value' != raw) {
      throw FormatException('$name must be a non-negative integer', raw);
    }
    return value;
  }

  static void _rejectUnknown(Map<String, String> query, Set<String> known) {
    for (final key in query.keys) {
      if (!known.contains(key)) {
        throw FormatException('Unknown page parameter "$key"');
      }
    }
  }
}

/// The page of a [DwPageRequest]: rows after [offset].
final class DwOffsetQuery extends DwPageQuery {
  const DwOffsetQuery({this.offset = 0, super.pageSize})
    : assert(offset >= 0, 'offset must not be negative');

  static DwOffsetQuery _parse(Map<String, String> query) {
    DwPageQuery._rejectUnknown(query, const {
      DwHttp.offsetParameter,
      DwHttp.pageSizeParameter,
    });
    final offset = query[DwHttp.offsetParameter];
    return DwOffsetQuery(
      offset: offset == null
          ? 0
          : DwPageQuery._readCount(offset, DwHttp.offsetParameter),
      pageSize: DwPageQuery._readPageSize(query),
    );
  }

  /// Rows already loaded.
  final int offset;

  @override
  Map<String, String> toQuery() => {
    if (offset != 0) DwHttp.offsetParameter: '$offset',
    if (pageSize != null) DwHttp.pageSizeParameter: '$pageSize',
  };

  @override
  bool operator ==(Object other) =>
      other is DwOffsetQuery &&
      other.offset == offset &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(offset, pageSize);

  @override
  String toString() => 'DwOffsetQuery(offset: $offset, pageSize: $pageSize)';
}

/// The rows of a [DwWindowRequest] a call reads: the newest, around an
/// anchor, or past a cursor of the window.
final class DwWindowQuery extends DwPageQuery {
  /// The newest rows: a window without an anchor.
  const DwWindowQuery.newest({super.pageSize})
    : direction = DwWindowDirection.around,
      cursor = null;

  /// The rows around the row of [anchor].
  const DwWindowQuery.around(String anchor, {super.pageSize})
    : direction = DwWindowDirection.around,
      cursor = anchor;

  /// The rows older than [before] — a window's `olderCursor`.
  const DwWindowQuery.older(String before, {super.pageSize})
    : direction = DwWindowDirection.older,
      cursor = before;

  /// The rows newer than [after] — a window's `newerCursor`.
  const DwWindowQuery.newer(String after, {super.pageSize})
    : direction = DwWindowDirection.newer,
      cursor = after;

  static DwWindowQuery _parse(Map<String, String> query) {
    DwPageQuery._rejectUnknown(query, const {
      DwHttp.anchorParameter,
      DwHttp.beforeParameter,
      DwHttp.afterParameter,
      DwHttp.pageSizeParameter,
    });
    final anchor = query[DwHttp.anchorParameter];
    final before = query[DwHttp.beforeParameter];
    final after = query[DwHttp.afterParameter];
    final pageSize = DwPageQuery._readPageSize(query);
    return switch ((anchor, before, after)) {
      (null, null, null) => DwWindowQuery.newest(pageSize: pageSize),
      (final String anchor, null, null) => DwWindowQuery.around(
        anchor,
        pageSize: pageSize,
      ),
      (null, final String before, null) => DwWindowQuery.older(
        before,
        pageSize: pageSize,
      ),
      (null, null, final String after) => DwWindowQuery.newer(
        after,
        pageSize: pageSize,
      ),
      _ => throw const FormatException(
        'A window call names at most one of anchor, before and after',
      ),
    };
  }

  final DwWindowDirection direction;

  /// The anchor ([DwWindowDirection.around]; `null` for the newest rows) or
  /// the cursor to read past. Opaque: a `DwWindowCursor` string.
  final String? cursor;

  @override
  Map<String, String> toQuery() => {
    switch (direction) {
      DwWindowDirection.around => DwHttp.anchorParameter,
      DwWindowDirection.older => DwHttp.beforeParameter,
      DwWindowDirection.newer => DwHttp.afterParameter,
    }: ?cursor,
    if (pageSize != null) DwHttp.pageSizeParameter: '$pageSize',
  };

  @override
  bool operator ==(Object other) =>
      other is DwWindowQuery &&
      other.direction == direction &&
      other.cursor == cursor &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(direction, cursor, pageSize);

  @override
  String toString() =>
      'DwWindowQuery(${direction.name}, cursor: $cursor, pageSize: $pageSize)';
}
