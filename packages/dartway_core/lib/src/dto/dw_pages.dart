import '../protocol/dw_json.dart';
import '../protocol/dw_read.dart';
import 'dw_dto.dart';

// The result shapes of the paginated request kinds. Each encodes its items
// untagged (the item type is the request's) and decodes them with the
// request's typed decoder, so a page keeps its reified item type.

List<Map<String, Object?>> _encodeItems(List<DwDataObject> items) => [
  for (final item in items) item.toJson(),
];

List<T> _decodeItems<T>(Object? json, T Function(Object? json) decodeItem) => [
  for (final item in dwReadList(json, 'items')) decodeItem(item),
];

/// One page of a `DwPageRequest`: the rows after the offset, and whether
/// more exist.
final class DwPage<T extends DwDataObject> {
  const DwPage(this.items, {required this.hasMore});

  /// Decodes a page; [decodeItem] is the request's item decoder.
  factory DwPage.fromJson(Object? json, T Function(Object? json) decodeItem) {
    final map = dwReadMap(json, 'A page');
    dwRejectUnknownKeys(map, const {'items', 'hasMore'}, 'A page');
    return DwPage(
      _decodeItems(map['items'], decodeItem),
      hasMore: dwReadBool(map['hasMore'], 'hasMore'),
    );
  }

  final List<T> items;

  /// Whether another page exists. The server learns it by reading one row past
  /// the page, never by counting.
  final bool hasMore;

  Map<String, Object?> toJson() => {
    'items': _encodeItems(items),
    'hasMore': hasMore,
  };

  @override
  bool operator ==(Object other) =>
      other is DwPage<T> &&
      other.hasMore == hasMore &&
      dwListEquals(other.items, items);

  @override
  int get hashCode => Object.hash(hasMore, Object.hashAll(items));

  @override
  String toString() => 'DwPage(${items.length} items, hasMore: $hasMore)';
}

/// One numbered page of a `DwTableRequest`.
final class DwTablePage<T extends DwDataObject> {
  /// Throws [ArgumentError] for a page that cannot exist: a page or page
  /// size below 1, a negative total, or more items than the page size.
  DwTablePage(
    this.items, {
    required this.total,
    required this.page,
    required this.pageSize,
  }) {
    if (page < 1) throw ArgumentError.value(page, 'page', 'must be at least 1');
    if (pageSize < 1) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be at least 1');
    }
    if (total < 0) throw ArgumentError.value(total, 'total', 'is negative');
    if (items.length > pageSize) {
      throw ArgumentError.value(
        items.length,
        'items',
        'a page holds at most pageSize ($pageSize) items',
      );
    }
  }

  /// Decodes a table page; [decodeItem] is the request's item decoder.
  factory DwTablePage.fromJson(
    Object? json,
    T Function(Object? json) decodeItem,
  ) {
    const what = 'A table page';
    final map = dwReadMap(json, what);
    dwRejectUnknownKeys(map, const {
      'items',
      'total',
      'page',
      'pageSize',
    }, what);
    final items = _decodeItems(map['items'], decodeItem);
    try {
      return DwTablePage(
        items,
        total: dwReadInt(map['total'], 'total'),
        page: dwReadInt(map['page'], 'page'),
        pageSize: dwReadInt(map['pageSize'], 'pageSize'),
      );
    } on ArgumentError catch (error) {
      throw FormatException('$what is inconsistent: ${error.message}');
    }
  }

  final List<T> items;

  /// Rows matching the request across all pages.
  final int total;

  /// This page's number, from 1.
  final int page;

  /// The rows per page the server served (the request's, clamped).
  final int pageSize;

  /// Pages at [pageSize]; 0 when there are no rows.
  int get pageCount => (total + pageSize - 1) ~/ pageSize;

  Map<String, Object?> toJson() => {
    'items': _encodeItems(items),
    'total': total,
    'page': page,
    'pageSize': pageSize,
  };

  @override
  bool operator ==(Object other) =>
      other is DwTablePage<T> &&
      other.total == total &&
      other.page == page &&
      other.pageSize == pageSize &&
      dwListEquals(other.items, items);

  @override
  int get hashCode => Object.hash(total, page, pageSize, Object.hashAll(items));

  @override
  String toString() =>
      'DwTablePage(page $page of $pageCount, ${items.length} items, total $total)';
}

/// A window of a `DwWindowRequest`: rows newest first, and the cursors to
/// read past either end.
///
/// A cursor is present exactly when rows exist past that end, so "has older"
/// and "the cursor to load them" are one fact and cannot disagree.
final class DwWindow<T extends DwDataObject> {
  /// Throws [ArgumentError] for a window with a cursor but no rows: a cursor
  /// names the row at an end of the window.
  DwWindow(this.items, {this.olderCursor, this.newerCursor}) {
    if (items.isEmpty && (olderCursor != null || newerCursor != null)) {
      throw ArgumentError(
        'An empty window has no ends, so it has no cursors: rows past an end '
        'would have been in the window.',
      );
    }
  }

  /// Decodes a window; [decodeItem] is the request's item decoder.
  factory DwWindow.fromJson(Object? json, T Function(Object? json) decodeItem) {
    const what = 'A window';
    final map = dwReadMap(json, what);
    dwRejectUnknownKeys(map, const {
      'items',
      'olderCursor',
      'newerCursor',
    }, what);
    final items = _decodeItems(map['items'], decodeItem);
    try {
      return DwWindow(
        items,
        olderCursor: dwReadOptionalString(map['olderCursor'], 'olderCursor'),
        newerCursor: dwReadOptionalString(map['newerCursor'], 'newerCursor'),
      );
    } on ArgumentError catch (error) {
      throw FormatException('$what is inconsistent: ${error.message}');
    }
  }

  /// Newest first.
  final List<T> items;

  /// Loads the rows older than the last item (`before`); `null` when there
  /// are none.
  final String? olderCursor;

  /// Loads the rows newer than the first item (`after`); `null` when the
  /// window shows the newest rows.
  final String? newerCursor;

  bool get hasOlder => olderCursor != null;

  /// Whether newer rows exist than the window shows. While `false`, a new row
  /// arriving live is inserted at the head.
  bool get hasNewer => newerCursor != null;

  Map<String, Object?> toJson() => {
    'items': _encodeItems(items),
    if (olderCursor != null) 'olderCursor': olderCursor,
    if (newerCursor != null) 'newerCursor': newerCursor,
  };

  @override
  bool operator ==(Object other) =>
      other is DwWindow<T> &&
      other.olderCursor == olderCursor &&
      other.newerCursor == newerCursor &&
      dwListEquals(other.items, items);

  @override
  int get hashCode =>
      Object.hash(olderCursor, newerCursor, Object.hashAll(items));

  @override
  String toString() =>
      'DwWindow(${items.length} items, hasOlder: $hasOlder, hasNewer: $hasNewer)';
}
