/// The legal initial values and directed moves of a state column.
/// Missing entries are terminal states; self moves must be explicit.
final class DwStateTransitions<S> {
  const DwStateTransitions({required this.initial, required this.moves});

  final Set<S> initial;
  final Map<S, Set<S>> moves;

  bool allows(S from, S to) => moves[from]?.contains(to) ?? false;

  Set<S> sourcesFor(S to) => {
    for (final entry in moves.entries)
      if (entry.value.contains(to)) entry.key,
  };
}
