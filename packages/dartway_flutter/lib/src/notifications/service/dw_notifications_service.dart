import 'dart:async';

class DwNotificationsService {
  final _controller = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _controller.stream;

  void emit(dynamic event) {
    _controller.add(event);
  }

  void dispose() => _controller.close();
}
