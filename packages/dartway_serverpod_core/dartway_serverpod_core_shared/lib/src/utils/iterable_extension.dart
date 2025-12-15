extension IterableExtensions<E> on Iterable<E> {
  E firstWhereOrThrow(bool Function(E element) test, [String? errorMessage]) {
    try {
      return firstWhere(test);
    } catch (_) {
      throw StateError(
          errorMessage ?? 'No element found matching the condition');
    }
  }
}
