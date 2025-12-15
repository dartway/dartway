// import 'dart:convert';
// import 'dart:io';

// import 'package:serverpod/serverpod.dart';

// import 'dw_web_server_logger.dart';

// mixin DwRouteLoggingMixin on Route {
//   Future<bool> handleLogged(
//     Session session,
//     HttpRequest request,
//     Future<bool> Function() handler,
//   ) async {
//     String? requestBody;

//     try {
//       // читаем тело 1 раз
//       if (request.method == 'POST' ||
//           request.method == 'PUT' ||
//           request.method == 'PATCH') {
//         try {
//           requestBody = await utf8.decoder.bind(request).join();
//         } catch (e) {
//           session.log('⚠️ Не удалось прочитать тело запроса: $e',
//               level: LogLevel.warning);
//         }
//       }

//       // логируем запрос (тело передаём явно)
//       await DwWebServerLogger.logRequest(session,
//           request: request, handler: runtimeType.toString(), handle: handle);

//       // выполняем основной код
//       final result = await handler();
//       return result;
//     } catch (e, st) {
//       session.log('❌ Route failed: $e',
//           level: LogLevel.error, exception: e, stackTrace: st);
//       rethrow;
//     }
//   }
// }
