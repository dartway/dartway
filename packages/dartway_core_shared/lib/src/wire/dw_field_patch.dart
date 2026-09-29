/// A field of a command that edits a value which may be cleared.
///
/// On the wire a kept field is absent, a set field carries its value and a
/// cleared field carries an explicit `null` — so "leave unchanged" and "set
/// to null" are different messages, which a plain nullable field cannot express
/// (#244: a save that answered success and wrote nothing).
///
/// Code on either side reads a patch through its members and [DwFieldPatchApply],
/// never by matching [DwSetField], [DwClearField] or [DwKeepField]: `dartway
/// check` refuses such a match in a project (`fieldPatchMatched`).
///
/// - an existing row: `row.copyWith(note: command.note)` — the generated
///   `copyWith` takes the patch as it is;
/// - a row being inserted: the same `copyWith` on the new row, or
///   `command.note.apply(null)` for a constructor argument — a kept field is
///   the column's default, which is what [DwFieldPatchApply.apply] of the
///   default answers;
/// - a text a person typed: [DwTextFieldPatch.trimmedOrCleared] first, so a
///   blank field clears rather than stores spaces;
/// - a check before writing: [isSet] with [DwFieldPatchApply.newValue];
/// - the patch of another field: [DwFieldPatchApply.map].
sealed class DwFieldPatch<T> {
  const DwFieldPatch();

  const factory DwFieldPatch.keep() = DwKeepField<T>;
  const factory DwFieldPatch.set(T value) = DwSetField<T>;
  const factory DwFieldPatch.clear() = DwClearField<T>;

  bool get isKept => this is DwKeepField;

  /// Whether the patch writes a value.
  bool get isSet => this is DwSetField;

  /// Whether the patch writes `null`.
  bool get isCleared => this is DwClearField;
}

/// Applying a patch, as an extension rather than a member.
///
/// A member `T? apply(T? current)` is checked against the patch's type
/// argument at run time. `const DwFieldPatch.clear()` and `.keep()` in a
/// context that cannot supply `T` — a conditional expression in a generic
/// function — are `DwClearField<Never>`: assignable to any `DwFieldPatch<T>`,
/// and a member `apply('x')` on them failed with "String is not a subtype of
/// Null". An extension is resolved by the static type, so the value a caller
/// passes is checked against the type it declared, not against `Never`.
extension DwFieldPatchApply<T> on DwFieldPatch<T> {
  /// Applies the patch to the current value.
  T? apply(T? current) => switch (this) {
    DwKeepField() => current,
    DwSetField(:final value) => value,
    DwClearField() => null,
  };

  /// The value the patch writes, or `null` when it keeps or clears — for a
  /// check that only concerns a new value (an owned file, a length):
  /// `if (command.coverFileId.newValue case final id?) …`.
  T? get newValue => switch (this) {
    DwSetField(:final value) => value,
    _ => null,
  };

  /// The same patch over another type: a set value converted by [convert],
  /// a keep or a clear as they are — a file id a command sets becoming the
  /// URL a data object shows.
  DwFieldPatch<U> map<U>(U Function(T value) convert) => switch (this) {
    DwSetField(:final value) => DwFieldPatch.set(convert(value)),
    DwClearField() => const DwFieldPatch.clear(),
    DwKeepField() => const DwFieldPatch.keep(),
  };
}

/// A text field as a person means it.
extension DwTextFieldPatch on DwFieldPatch<String> {
  /// A set value trimmed, and a blank one — empty or only spaces — turned into
  /// a clear: an emptied text field means "no value", never a stored blank.
  /// A kept or cleared patch is returned as it is.
  DwFieldPatch<String> get trimmedOrCleared => switch (this) {
    DwSetField(:final value) => switch (value.trim()) {
      '' => const DwFieldPatch.clear(),
      final trimmed => DwFieldPatch.set(trimmed),
    },
    final other => other,
  };
}

final class DwKeepField<T> extends DwFieldPatch<T> {
  const DwKeepField();

  @override
  bool operator ==(Object other) => other is DwKeepField;

  @override
  int get hashCode => 0;
}

final class DwSetField<T> extends DwFieldPatch<T> {
  const DwSetField(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is DwSetField && other.value == value;

  @override
  int get hashCode => Object.hash(1, value);
}

final class DwClearField<T> extends DwFieldPatch<T> {
  const DwClearField();

  @override
  bool operator ==(Object other) => other is DwClearField;

  @override
  int get hashCode => 2;
}
