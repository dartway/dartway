import 'dart:async';

/// Records what a stream emits, for assertions over a sequence of states.
///
/// ```dart
/// final states = DwStreamRecording(watch.states);
/// await pumpEventQueue();
/// expect(states.last, isA<DwRequestData<List<RoomView>>>());
/// ```
final class DwStreamRecording<T> {
  DwStreamRecording(Stream<T> stream) {
    _subscription = stream.listen(
      _values.add,
      onError: errors.add,
      onDone: () => _done = true,
    );
  }

  late final StreamSubscription<T> _subscription;
  final List<T> _values = [];
  bool _done = false;

  /// Every value so far, in order.
  List<T> get values => List.unmodifiable(_values);

  /// The latest value. Throws when nothing was recorded.
  T get last => _values.last;

  /// Errors the stream emitted.
  final List<Object> errors = [];

  /// Whether the stream is done.
  bool get isDone => _done;

  /// Forgets what was recorded so far; recording continues.
  void clear() => _values.clear();

  Future<void> cancel() => _subscription.cancel();
}
