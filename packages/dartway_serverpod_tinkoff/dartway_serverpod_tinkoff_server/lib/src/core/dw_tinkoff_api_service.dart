import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_serverpod_tinkoff_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/dw_tinkoff_api_method_extension.dart';
import '../domain/dw_tinkoff_api_request.dart';
import '../utils/dw_tinkoff_http_client.dart';

/// Сервис для отправки подписанных запросов к API Тинькофф
class DwTinkoffService {
  static final String _apiUrl = 'https://securepay.tinkoff.ru';

  static late final String _terminalKey;
  static late final String _password;
  static late final String _notificationsUrl;
  static late final String _successRedirectUrl;
  static late final String _failRedirectUrl;

  static late final String? _proxyAddress;
  static late final String? _proxyCredentials;

  /// Инициализация конфигурации из секретов Serverpod
  static void init(Map<String, String> passwords) {
    _terminalKey = passwords['dwTinkoffTerminalKey']!;
    _password = passwords['dwTinkoffPassword']!;
    _notificationsUrl = passwords['dwTinkoffNotificationsUrl']!;
    _successRedirectUrl = passwords['dwTinkoffSuccessRedirectUrl']!;
    _failRedirectUrl = passwords['dwTinkoffFailRedirectUrl']!;
    _proxyAddress = passwords['dwTinkoffProxyAddress'];
    _proxyCredentials = passwords['dwTinkoffProxyCredentials'];
  }

  static Future<T?> processApiRequest<T>(
    Session session,
    DwTinkoffApiRequest<T> request,
  ) async {
    final uri = Uri.parse('$_apiUrl${request.method.endpoint}');
    final payload =
        _prepareBody(request.params, withWebHooks: request.withWebHooks);

    final client = DwTinkoffHttpClient(
      proxyAddress: _proxyAddress,
      proxyCredentials: _proxyCredentials,
    );

    final response = await client.postJson(uri, payload);
    client.close();

    final json = jsonDecode(response.body);
    final isSuccess = response.statusCode == 200 && json['Success'] == true;

    final errorMessage = !isSuccess
        ? json['Message'] ??
            'Ошибка ${response.statusCode} ${response.reasonPhrase} при выполнении запроса ${request.method.name}'
        : null;

    await DwTinkoffLog.db.insertRow(
      session,
      DwTinkoffLog(
        timestamp: DateTime.now(),
        logType: DwTinkoffLogType.apiRequest,
        method: request.method,
        endpoint: request.method.endpoint,
        paramsString: request.params.toString(),
        tinkoffCustomerId: request.params['CustomerKey'],
        isOk: isSuccess,
        statusCode: response.statusCode,
        statusMessage: response.reasonPhrase,
        error: errorMessage,
        errorDetails: json['Details'],
        responseData: response.body,
      ),
    );

    if (errorMessage != null) {
      session.log(errorMessage);
      return null;
    }

    return await request.processResponse(
      session,
      payload,
      response,
    );
  }

  // /// Отправка запроса к API Тинькофф
  // static Future<T?> processApiRequest<T>(
  //   Session session,
  //   DwTinkoffApiRequest<T> request,
  // ) async {
  //   final body = jsonEncode(
  //     _prepareBody(
  //       request.params,
  //       withWebHooks: request.withWebHooks,
  //     ),
  //   );

  //   final ioClient = HttpClient()
  //     ..badCertificateCallback =
  //         (X509Certificate cert, String host, int port) => true;
  //   ;

  //   if (_proxyAddress != null && _proxyCredentials != null) {
  //     ioClient.findProxy = (uri) => "PROXY $_proxyCredentials@$_proxyAddress";
  //   }

  //   final client = IOClient(ioClient);

  //   late http.Response response;

  //   try {
  //     response = await client.post(
  //       Uri.parse('$_apiUrl${request.method.endpoint}'),
  //       headers: {
  //         HttpHeaders.contentTypeHeader: 'application/json',
  //       },
  //       body: body,
  //     );
  //   } finally {
  //     client.close();
  //   }

  //   final responseJson = jsonDecode(response.body);
  //   final isSuccess =
  //       response.statusCode == 200 && responseJson['Success'] == true;

  //   final errorMessage = !isSuccess
  //       ? responseJson['Message'] ??
  //           'Ошибка ${response.statusCode} ${response.reasonPhrase} при выполнении запроса ${request.method.name}'
  //       : null;

  //   if (errorMessage != null) session.log(errorMessage);

  //   await DwTinkoffLog.db.insertRow(
  //     session,
  //     DwTinkoffLog(
  //       timestamp: DateTime.now(),
  //       logType: DwTinkoffLogType.apiRequest,
  //       method: request.method,
  //       endpoint: request.method.endpoint,
  //       paramsString: request.params.toString(),
  //       tinkoffCustomerId: request.params['CustomerKey'],
  //       isOk: isSuccess,
  //       statusCode: response.statusCode,
  //       statusMessage: response.reasonPhrase,
  //       error: errorMessage,
  //       errorDetails: responseJson['Details'],
  //       responseData: response.body,
  //     ),
  //   );

  //   return await request.processResponse(session, response);
  // }

  /// Подготовка тела запроса с добавлением стандартных полей и подписью
  static Map<String, dynamic> _prepareBody(
    Map<String, dynamic> data, {
    bool withWebHooks = false,
  }) {
    final fullData = {
      ...data,
      'TerminalKey': _terminalKey,
      if (withWebHooks) ...{
        'SuccessURL': _successRedirectUrl,
        'FailURL': _failRedirectUrl,
        'NotificationURL': _notificationsUrl,
      },
    };

    return {
      ...fullData,
      'Token': _getToken(fullData, _password),
    };
  }

  /// Генерация подписи по алфавитно отсортированным значениям с добавлением пароля
  static String _getToken(Map<String, dynamic> data, String password) {
    final cleaned = Map<String, String>.fromEntries(
      data.entries
          .where((e) => _isPrimitive(e.value))
          .map((e) => MapEntry(e.key.toString(), e.value.toString())),
    )..['Password'] = password;

    final sorted = SplayTreeMap<String, String>.from(cleaned);
    final joined = sorted.values.join();

    return sha256.convert(utf8.encode(joined)).toString();
  }

  /// Проверка, является ли значение допустимым для подписи
  static bool _isPrimitive(dynamic value) =>
      value is String || value is num || value is bool;
}
