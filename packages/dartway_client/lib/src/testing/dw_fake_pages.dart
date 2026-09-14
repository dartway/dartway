import 'package:dartway_core/dartway_core.dart';

/// The page of [ordered] a [DwPageRequest] call asks for, as a DartWay
/// server serves it: rows after the offset, at the size the request serves
/// for the call, reading one row past the page to learn `hasMore`.
DwPageResult<T> dwFakeOffsetPage<T extends DwDataObject>(
  List<T> ordered,
  DwPageRequest<T> request,
  DwPageQuery? page,
) {
  final query = page is DwOffsetQuery ? page : const DwOffsetQuery();
  final size = request.servedPageSize(query.pageSize);
  final rows = ordered.skip(query.offset).take(size + 1).toList();
  return DwPageResult<T>(rows.take(size).toList(), hasMore: rows.length > size);
}

/// The numbered page of [ordered] a [DwTableRequest] asks for.
DwTablePage<T> dwFakeTablePage<T extends DwDataObject>(
  List<T> ordered,
  DwTableRequest<T> request,
) {
  final size = request.servedPageSize;
  return DwTablePage<T>(
    ordered.skip(request.offset).take(size).toList(),
    total: ordered.length,
    page: request.page,
    pageSize: size,
  );
}

/// The window of [newestFirst] a [DwWindowRequest] call asks for, with the
/// cursors a DartWay server builds: `DwWindowCursor(sortValue(row), row.id)`.
///
/// [newestFirst] must be ordered by that pair, descending. Around an anchor
/// the window holds the anchor row and the rows older than it, with up to
/// half of the page newer than it.
DwWindowResult<T> dwFakeWindow<T extends DwDataObject>(
  List<T> newestFirst,
  DwWindowRequest<T> request,
  DwPageQuery? page, {
  required Object Function(T row) sortValue,
}) {
  final query = page is DwWindowQuery ? page : const DwWindowQuery.newest();
  final size = request.servedPageSize(query.pageSize);
  DwWindowCursor keyOf(T row) => DwWindowCursor(sortValue(row), row.id);

  // Positions in newest-first order: rows before `index` are newer.
  int firstNotNewerThan(DwWindowCursor cursor) {
    final index = newestFirst.indexWhere(
      (row) => _compare(keyOf(row), cursor) <= 0,
    );
    return index < 0 ? newestFirst.length : index;
  }

  final int start;
  final int end;
  switch ((query.direction, query.cursor)) {
    case (DwWindowDirection.around, null):
      start = 0;
      end = size;
    case (DwWindowDirection.around, final String anchor):
      final at = firstNotNewerThan(DwWindowCursor.decode(anchor));
      final newer = size ~/ 2;
      start = at - newer < 0 ? 0 : at - newer;
      end = start + size;
    case (DwWindowDirection.older, final String before):
      final cursor = DwWindowCursor.decode(before);
      final at = newestFirst.indexWhere(
        (row) => _compare(keyOf(row), cursor) < 0,
      );
      start = at < 0 ? newestFirst.length : at;
      end = start + size;
    case (DwWindowDirection.newer, final String after):
      final at = firstNotNewerThan(DwWindowCursor.decode(after));
      end = at;
      start = end - size < 0 ? 0 : end - size;
    default:
      throw ArgumentError('A window read past an end names its cursor');
  }
  final clampedEnd = end > newestFirst.length ? newestFirst.length : end;
  final rows = newestFirst.sublist(start, clampedEnd);
  if (rows.isEmpty) return DwWindowResult<T>(rows);
  return DwWindowResult<T>(
    rows,
    olderCursor: clampedEnd < newestFirst.length
        ? keyOf(rows.last).encoded
        : null,
    newerCursor: start > 0 ? keyOf(rows.first).encoded : null,
  );
}

int _compare(DwWindowCursor a, DwWindowCursor b) {
  final bySort = (a.sortValue as Comparable<Object>).compareTo(b.sortValue);
  if (bySort != 0) return bySort;
  return (a.id as Comparable<Object>).compareTo(b.id);
}
