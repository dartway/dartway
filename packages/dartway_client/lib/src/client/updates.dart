part of 'dw_client.dart';

/// What applying one update to a request's value produced.
sealed class _Outcome {
  const _Outcome();
}

final class _Unchanged extends _Outcome {
  const _Unchanged();
}

final class _Changed extends _Outcome {
  const _Changed(this.value);

  final Object? value;
}

final class _Refetch extends _Outcome {
  const _Refetch();
}

const _unchanged = _Unchanged();
const _refetch = _Refetch();

/// The `onUpdate` rules of the request kinds (SPEC §4), applied to values.
///
/// **Values keep their reified types.** A list state is a `List<T>` built by
/// the request's own decoder; every change copies it with `toList()`, which
/// keeps `T`, and only ever inserts objects already shown to be `T`. The rules
/// themselves see those lists as `List<DwDataObject>`, because one set of rules
/// serves every item type.
final class _UpdateRules {
  _UpdateRules(this.protocol);

  final DwProtocol protocol;

  /// Request type → object type → whether the object is the request's item
  /// type. Both are runtime types of generated, non-generic classes, so the
  /// answer never changes and is computed once per pair.
  final Map<Type, Map<Type, bool>> _accepts = {};

  /// Whether [object] is the item type `T` of [request]'s kind.
  ///
  /// `dartway_core`'s kinds keep `T` to themselves: nothing on a request says
  /// what its item type is, and `object is T` can only be written where `T` is
  /// in scope. What *does* know `T` is the request's own decoder, which calls
  /// `protocol.decodeAs<T>`. So the question is put to it: decode a stub with a
  /// protocol that registers exactly the object's class, and the decoder finds
  /// an entry precisely when `T` is that class. Registration is by exact type,
  /// which is also exactly what the real decoder accepts — a request can only
  /// ever hold instances of a class registered as its `T`.
  ///
  /// A negative answer is a `StateError` thrown by `decodeAs`; explicit throws
  /// survive every compiler mode, unlike implicit type checks, which dart2js
  /// may omit in release builds. The cost is paid once per type pair.
  bool accepts(DwRequest<Object?> request, DwDataObject object) =>
      (_accepts[request.runtimeType] ??= {})[object.runtimeType] ??= _probe(
        request,
        object,
      );

  bool _probe(DwRequest<Object?> request, DwDataObject object) {
    const stub = <String, Object?>{};
    final Object json;
    switch (request) {
      case DwListRequest():
        json = const [stub];
      case DwSingleRequest() || DwMaybeRequest():
        json = stub;
      case DwPageRequest() || DwCursorRequest():
        json = const {
          'items': [stub],
          'more': false,
        };
      default:
        return false;
    }
    final probe = DwProtocol([
      DwDtoEntry(object.runtimeType, object.dwTypeName, (_) => object),
    ]);
    try {
      request.decodeResult(json, probe);
      return true;
    } on StateError {
      return false;
    }
  }

  /// Applies [item] to the value of a whole-value request.
  _Outcome applyToValue(DwRequest<Object?> request, Object? value, DwDto item) {
    final action = request.onUpdate(item);
    if (action == DwUpdate.ignore) return _unchanged;
    if (action == DwUpdate.refetch) return _refetch;
    return switch (request) {
      DwSingleRequest() => _single(
        request,
        value! as DwDataObject,
        item,
        action,
      ),
      DwMaybeRequest() => _maybe(request, value as DwDataObject?, item, action),
      DwListRequest() => _items(
        request,
        value! as List<DwDataObject>,
        item,
        action,
        matches: request.matches,
        sort: _sortOf(request),
        dropPastEnd: false,
      ),
      // A request that extends no kind has no default to fall back on.
      _ =>
        action == DwUpdate.auto
            ? _unchanged
            : throw _misuse(
                request,
                item,
                action,
                'it extends no request kind',
              ),
    };
  }

  /// Applies [item] to the loaded items of a paginated request.
  _Outcome applyToPages(
    DwRequest<Object?> request,
    List<DwDataObject> items,
    bool hasMore,
    DwDto item,
  ) {
    final action = request.onUpdate(item);
    if (action == DwUpdate.ignore) return _unchanged;
    if (action == DwUpdate.refetch) return _refetch;
    return switch (request) {
      // An object sorting past the loaded pages is left to arrive on scroll;
      // inserting it at the end would also shift the offset of the next page.
      DwPageRequest() => _items(
        request,
        items,
        item,
        action,
        matches: request.matches,
        sort: _sortOf(request),
        dropPastEnd: hasMore,
      ),
      // Cursor pages are newest first, and a new object is the newest.
      DwCursorRequest() => _items(
        request,
        items,
        item,
        action,
        matches: request.matches,
        sort: null,
        dropPastEnd: false,
      ),
      _ => throw StateError('${request.dwTypeName} is not paginated.'),
    };
  }

  _Outcome _single(
    DwRequest<Object?> request,
    DwDataObject current,
    DwDto item,
    DwUpdate action,
  ) {
    if (item is DwDeleted) {
      if (action == DwUpdate.upsert) {
        throw _misuse(request, item, action, 'a deletion cannot be inserted');
      }
      // The object is gone; asking again makes the server answer not-found,
      // which is the state the screen has to show.
      return _isDeletionOf(item, current) ? _refetch : _unchanged;
    }
    if (item is! DwDataObject || !accepts(request, item)) {
      return _foreign(request, item, action);
    }
    return switch (action) {
      DwUpdate.remove => item.id == current.id ? _refetch : _unchanged,
      DwUpdate.upsert => item == current ? _unchanged : _Changed(item),
      _ =>
        item.id == current.id && item != current ? _Changed(item) : _unchanged,
    };
  }

  _Outcome _maybe(
    DwMaybeRequest<DwDataObject> request,
    DwDataObject? current,
    DwDto item,
    DwUpdate action,
  ) {
    if (item is DwDeleted) {
      if (action == DwUpdate.upsert) {
        throw _misuse(request, item, action, 'a deletion cannot be inserted');
      }
      return current != null && _isDeletionOf(item, current)
          ? const _Changed(null)
          : _unchanged;
    }
    if (item is! DwDataObject || !accepts(request, item)) {
      return _foreign(request, item, action);
    }
    switch (action) {
      case DwUpdate.remove:
        return current != null && current.id == item.id
            ? const _Changed(null)
            : _unchanged;
      case DwUpdate.upsert:
        return item == current ? _unchanged : _Changed(item);
      default:
        if (current != null) {
          return current.id == item.id && current != item
              ? _Changed(item)
              : _unchanged;
        }
        // #242: a request that answered "none" hears about the row once it
        // exists.
        return request.matches(item) ? _Changed(item) : _unchanged;
    }
  }

  _Outcome _items(
    DwRequest<Object?> request,
    List<DwDataObject> items,
    DwDto item,
    DwUpdate action, {
    required bool Function(DwDataObject object) matches,
    required Function? sort,
    required bool dropPastEnd,
  }) {
    if (item is DwDeleted) {
      if (action == DwUpdate.upsert) {
        throw _misuse(request, item, action, 'a deletion cannot be inserted');
      }
      final index = items.indexWhere((e) => _isDeletionOf(item, e));
      return index < 0 ? _unchanged : _Changed(items.toList()..removeAt(index));
    }
    if (item is! DwDataObject || !accepts(request, item)) {
      return _foreign(request, item, action);
    }
    final index = items.indexWhere((e) => e.id == item.id);
    if (action == DwUpdate.remove) {
      return index < 0 ? _unchanged : _Changed(items.toList()..removeAt(index));
    }
    if (index >= 0) {
      // Replaced where it stands, never moved: a liked post must not jump to
      // the top of a feed (the U90 lesson).
      return items[index] == item
          ? _unchanged
          : _Changed(items.toList()..[index] = item);
    }
    if (action == DwUpdate.auto && !matches(item)) return _unchanged;
    final position = sort == null ? 0 : _insertionIndex(items, item, sort);
    if (sort != null && dropPastEnd && position == items.length) {
      return _unchanged;
    }
    return _Changed(items.toList()..insert(position, item));
  }

  /// An object that is not the request's item type: not its business by
  /// default, impossible to remove, and a programming error to insert.
  _Outcome _foreign(DwRequest<Object?> request, DwDto item, DwUpdate action) {
    if (action == DwUpdate.upsert) {
      throw _misuse(request, item, action, 'it is not the item type');
    }
    return _unchanged;
  }

  bool _isDeletionOf(DwDeleted deletion, DwDataObject object) =>
      object.id == deletion.id &&
      protocol.knows(object.runtimeType) &&
      protocol.nameOf(object.runtimeType) == deletion.typeName;

  /// The first position whose object sorts after [item]; the end if none.
  static int _insertionIndex(
    List<DwDataObject> items,
    DwDataObject item,
    Function sort,
  ) {
    for (var i = 0; i < items.length; i++) {
      if ((sort(item, items[i]) as int) < 0) return i;
    }
    return items.length;
  }

  /// `sort` read without a static item type.
  ///
  /// Its type, `int Function(T, T)?`, has `T` in a parameter position, so
  /// reading it through `DwListRequest<DwDataObject>` fails the soundness check
  /// Dart inserts for such getters. A dynamic read carries no expected type;
  /// the comparator is then only ever called with objects that are `T`.
  static Function? _sortOf(DwRequest<Object?> request) =>
      (request as dynamic).sort as Function?;

  static StateError _misuse(
    DwRequest<Object?> request,
    DwDto item,
    DwUpdate action,
    String why,
  ) => StateError(
    '${request.dwTypeName}.onUpdate answered ${action.name} for '
    '${item.dwTypeName}, and $why. The update was not applied.',
  );
}

/// Whether two values of one request are equal in content, so the older
/// instance can be kept and nobody watching it is told about a change that is
/// not one. Lists compare element-wise: generated DTOs compare by value, lists
/// by identity.
bool _sameValue(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) return dwListEquals(a, b);
  return a == b;
}
