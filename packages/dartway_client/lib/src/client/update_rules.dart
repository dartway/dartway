part of 'dw_app_client.dart';

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

/// The update actions of `DwUpdateAction`, applied to values (CONTRACTS R2.3).
///
/// Every object reaching here was accepted by the request (`acceptsItem` or
/// `acceptsDeletion`), so an item is of the request's item type and a
/// deletion names that type: matching by id is enough.
///
/// **Values keep their reified types.** A list state is a `List<T>` built by
/// the request's own decoder; every change copies it with `toList()`, which
/// keeps `T`, and only inserts objects `acceptsItem` has shown to be `T`. The
/// rules see those lists as `List<DwDataObject>`, because one set of rules
/// serves every item type.
abstract final class _UpdateRules {
  static _Outcome applyToValue(
    _Entry entry,
    Object? value,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    if (action == DwUpdateAction.ignore) return _unchanged;
    if (action == DwUpdateAction.refetch) return _refetch;
    final request = entry.request;
    return switch (request) {
      DwSingleRequest() => _single(
        entry,
        value! as DwDataObject,
        object,
        action,
      ),
      DwMaybeRequest() => _maybe(entry, value as DwDataObject?, object, action),
      DwListRequest() => items(
        entry,
        value! as List<DwDataObject>,
        object,
        action,
        sort: _sortOf(request),
        dropPastEnd: false,
      ),
      DwTableRequest() => _table(entry, value! as DwTablePage, object, action),
      DwPageRequest() || DwWindowRequest() => throw StateError(
        'unreachable: ${request.dwTypeName} has an entry of its own',
      ),
    };
  }

  static Object _idOf(DwWireObject object) => switch (object) {
    DwDeletedObject(:final id) => id,
    DwDataObject(:final id) => id,
    _ => throw StateError(
      'unreachable: a transport holds no ${object.dwTypeName}',
    ),
  };

  /// Single: the value is always present. Replaced when the same id arrives;
  /// its removal asks again, and the server answers what is now true
  /// (`dw.notFound`).
  static _Outcome _single(
    _Entry entry,
    DwDataObject current,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    if (_idOf(object) != current.id) return _unchanged;
    switch (action) {
      case DwUpdateAction.remove:
        return _refetch;
      case DwUpdateAction.update || DwUpdateAction.upsert:
        if (object is DwDeletedObject) {
          entry.misuse(object, action, 'a deletion cannot replace a value');
          return _unchanged;
        }
        return object == current ? _unchanged : _Changed(object);
      case DwUpdateAction.refetch || DwUpdateAction.ignore:
        throw StateError('unreachable: handled above');
    }
  }

  /// Maybe: an upsert fills or replaces the value — the request's default
  /// answers it only for an object that `matches`, the one asked for — an
  /// update replaces only the held object, a removal of it empties.
  static _Outcome _maybe(
    _Entry entry,
    DwDataObject? current,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    final id = _idOf(object);
    switch (action) {
      case DwUpdateAction.remove:
        return current != null && current.id == id
            ? const _Changed(null)
            : _unchanged;
      case DwUpdateAction.update || DwUpdateAction.upsert:
        if (object is DwDeletedObject) {
          entry.misuse(object, action, 'a deletion cannot fill a value');
          return _unchanged;
        }
        if (action == DwUpdateAction.update &&
            (current == null || current.id != id)) {
          return _unchanged;
        }
        return object == current ? _unchanged : _Changed(object);
      case DwUpdateAction.refetch || DwUpdateAction.ignore:
        throw StateError('unreachable: handled above');
    }
  }

  /// A list of items: upsert replaces in place or inserts by [sort] (at the
  /// head without one); update replaces only; remove removes. An object
  /// already in the list is never moved — a liked post must not jump to the
  /// top of a feed.
  ///
  /// [dropPastEnd]: a page feed with more pages drops an insert that sorts
  /// past its loaded rows; it arrives on scroll, and inserting it at the end
  /// would also shift the offset of the next page.
  static _Outcome items(
    _Entry entry,
    List<DwDataObject> items,
    DwWireObject object,
    DwUpdateAction action, {
    required Function? sort,
    required bool dropPastEnd,
  }) {
    final id = _idOf(object);
    final index = items.indexWhere((item) => item.id == id);
    switch (action) {
      case DwUpdateAction.remove:
        return index < 0
            ? _unchanged
            : _Changed(items.toList()..removeAt(index));
      case DwUpdateAction.update || DwUpdateAction.upsert:
        if (object is! DwDataObject) {
          entry.misuse(object, action, 'a deletion cannot be inserted');
          return _unchanged;
        }
        if (index >= 0) {
          return items[index] == object
              ? _unchanged
              : _Changed(items.toList()..[index] = object);
        }
        if (action == DwUpdateAction.update) return _unchanged;
        final position = sort == null
            ? 0
            : _insertionIndex(items, object, sort);
        if (sort != null && dropPastEnd && position == items.length) {
          return _unchanged;
        }
        return _Changed(items.toList()..insert(position, object));
      case DwUpdateAction.refetch || DwUpdateAction.ignore:
        throw StateError('unreachable: handled above');
    }
  }

  /// A numbered page never grows by an update: upsert and update replace an
  /// item on the page; a removal reads the page again, because every later
  /// row moves up — whether or not the removed one was on this page.
  static _Outcome _table(
    _Entry entry,
    DwTablePage page,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    if (action == DwUpdateAction.remove) return _refetch;
    final changed = items(
      entry,
      page.items,
      object,
      DwUpdateAction.update,
      sort: null,
      dropPastEnd: false,
    );
    if (changed is! _Changed) return changed;
    return _Changed(
      (entry as _TableEntry).withItems(
        page,
        changed.value! as List<DwDataObject>,
      ),
    );
  }

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
  /// reading it through `DwListRequest<DwDataObject>` fails the soundness
  /// check Dart inserts for such getters. A dynamic read carries no expected
  /// type; the comparator is then only ever called with objects that are `T`.
  static Function? _sortOf(DwDataRequest<Object?> request) =>
      (request as dynamic).sort as Function?;
}
