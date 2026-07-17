/// Internal to `dartway_serverpod_core_server` — an extension on `Iterable` is
/// visible to every file that imports it, so this one stays off the barrel.
extension DwIterableExtensions<E> on Iterable<E> {
  E firstWhereOrThrow(bool Function(E element) test, [String? errorMessage]) {
    try {
      return firstWhere(test);
    } catch (_) {
      throw StateError(
        errorMessage ?? 'No element found matching the condition',
      );
    }
  }
}
