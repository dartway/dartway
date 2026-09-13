/// A field of a command that edits a value which may be cleared.
///
/// On the wire a kept field is absent, a set field carries its value and a
/// cleared field carries an explicit `null` — so "leave unchanged" and "set to
/// null" are different messages, which a plain nullable field cannot express
/// (#244: a save that answered success and wrote nothing).
sealed class DwPatch<T> {
  const DwPatch();

  const factory DwPatch.keep() = DwKeep<T>;
  const factory DwPatch.set(T value) = DwSet<T>;
  const factory DwPatch.clear() = DwClear<T>;

  /// Applies the patch to the current value.
  T? apply(T? current) => switch (this) {
    DwKeep() => current,
    DwSet(:final value) => value,
    DwClear() => null,
  };

  bool get isKept => this is DwKeep<T>;
}

final class DwKeep<T> extends DwPatch<T> {
  const DwKeep();

  @override
  bool operator ==(Object other) => other is DwKeep;

  @override
  int get hashCode => 0;
}

final class DwSet<T> extends DwPatch<T> {
  const DwSet(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is DwSet && other.value == value;

  @override
  int get hashCode => Object.hash(1, value);
}

final class DwClear<T> extends DwPatch<T> {
  const DwClear();

  @override
  bool operator ==(Object other) => other is DwClear;

  @override
  int get hashCode => 2;
}
