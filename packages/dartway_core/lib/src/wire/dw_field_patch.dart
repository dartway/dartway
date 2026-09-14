/// A field of a command that edits a value which may be cleared.
///
/// On the wire a kept field is absent, a set field carries its value and a
/// cleared field carries an explicit `null` — so "leave unchanged" and "set
/// to null" are different messages, which a plain nullable field cannot express
/// (#244: a save that answered success and wrote nothing).
sealed class DwFieldPatch<T> {
  const DwFieldPatch();

  const factory DwFieldPatch.keep() = DwKeepField<T>;
  const factory DwFieldPatch.set(T value) = DwSetField<T>;
  const factory DwFieldPatch.clear() = DwClearField<T>;

  /// Applies the patch to the current value.
  T? apply(T? current) => switch (this) {
    DwKeepField() => current,
    DwSetField(:final value) => value,
    DwClearField() => null,
  };

  bool get isKept => this is DwKeepField<T>;
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
