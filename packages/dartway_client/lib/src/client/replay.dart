part of 'dw_client.dart';

/// A value with a stream that starts with the current value — what a new
/// listener needs to render at once — and then carries each change.
final class _Replay<T> {
  _Replay(this._value);

  T _value;
  bool _closed = false;
  final Set<MultiStreamController<T>> _listeners = {};

  T get value => _value;

  set value(T next) {
    if (_closed || next == _value) return;
    _value = next;
    for (final listener in _listeners.toList()) {
      listener.add(next);
    }
  }

  Stream<T> get stream => Stream.multi((controller) {
    controller.add(_value);
    if (_closed) {
      controller.close();
      return;
    }
    _listeners.add(controller);
    controller.onCancel = () => _listeners.remove(controller);
  });

  void close() {
    _closed = true;
    for (final listener in _listeners.toList()) {
      listener.close();
    }
    _listeners.clear();
  }
}
