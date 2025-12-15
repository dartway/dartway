import 'dw_notifications_service.dart';

class DwNotificationsController {
  static DwNotificationsService? _service;

  static void register(DwNotificationsService service) {
    _service = service;
  }

  static void emit(dynamic event) {
    _service?.emit(event);
  }
}
