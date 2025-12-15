import 'dart:convert';

import 'package:dartway_serverpod_tinkoff_server/src/domain/dw_tinkoff_payment_extension.dart';
import 'package:dartway_serverpod_tinkoff_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import '../utils/dw_tinkoff_http_client.dart'; // подключаем SimpleHttpResponse
import 'dw_tinkoff_operation_initiator_type.dart';

/// Объект описывает один конкретный вызов API Тинькофф:
/// - какой метод вызвать (`method`)
/// - какие параметры передать (`params`)
/// - как обработать ответ (`processResponse`)
///
/// Используется внутри `DwTinkoffService` как единая точка описания бизнес-вызовов.
class DwTinkoffApiRequest<T> {
  DwTinkoffApiRequest({
    required this.method,
    required this.params,
    required this.processResponse,
    this.withWebHooks = false,
  });

  /// Метод API, который будет вызван (например, `initPayment`)
  final DwTinkoffApiMethod method;

  /// Параметры запроса — отправляются в теле POST-запроса
  final Map<String, dynamic> params;

  /// Обработка ответа от API
  ///
  /// Получает:
  /// - `session` — для работы с БД или логированием
  /// - `SimpleHttpResponse` — упрощённый HTTP-ответ
  ///
  /// Возвращает значение типа `T`, либо `null` в случае ошибки.
  final Future<T?> Function(
    Session session,
    Map<String, dynamic> requestParams,
    SimpleHttpResponse response,
  ) processResponse;

  /// Используется ли данный метод с webhook-нотификациями
  final bool withWebHooks;

  /// Универсальная функция для boolean-ответов (Success == true && HTTP 200)
  static Future<bool> _isOk(
      Session _, Map<String, dynamic> __, SimpleHttpResponse response) async {
    final json = jsonDecode(response.body);
    return response.statusCode == 200 && json['Success'] == true;
  }

  /// Запрос на получение информации о клиенте
  static DwTinkoffApiRequest<bool> getCustomer({required int customerId}) =>
      DwTinkoffApiRequest<bool>(
        method: DwTinkoffApiMethod.getCustomer,
        params: {
          'CustomerKey': '$customerId',
        },
        processResponse: _isOk,
      );

  /// Запрос на создание клиента
  static DwTinkoffApiRequest<bool> addCustomer({required int customerId}) =>
      DwTinkoffApiRequest<bool>(
        method: DwTinkoffApiMethod.addCustomer,
        params: {
          'CustomerKey': '$customerId',
        },
        processResponse: _isOk,
      );

  /// Запрос на отмену платежа
  static DwTinkoffApiRequest<bool> cancelPayment({required String paymentId}) =>
      DwTinkoffApiRequest<bool>(
        method: DwTinkoffApiMethod.cancelPayment,
        params: {
          'PaymentId': paymentId,
        },
        processResponse: _isOk,
      );

  /// Запрос на инициализацию платежа (Init)
  ///
  /// Возвращает и сохраняет объект `DwTinkoffPayment` в базе
  static DwTinkoffApiRequest<DwTinkoffPayment> initPayment({
    required int customerId,
    required int amountInCents,
    required String orderIdentifier,
    required String description,
    required DwTinkoffOperationInitiatorType operationInitiatorType,
    Map<String, dynamic>? receiptData,
  }) =>
      DwTinkoffApiRequest<DwTinkoffPayment>(
        method: DwTinkoffApiMethod.initPayment,
        params: {
          'CustomerKey': '$customerId',
          'Amount': amountInCents.toString(),
          'OrderId': orderIdentifier,
          'Description': description,
          if (operationInitiatorType.requestRebillId) 'Recurrent': 'Y',
          'OperationInitiatorType': operationInitiatorType.apiValue,
          if (receiptData != null) 'Receipt': receiptData,
        },
        withWebHooks: true,
        processResponse: (session, requestParams, response) async {
          return await session.db.insertRow(
            DwTinkoffPaymentExtension.fromInitPaymentResponse(
              orderIdentifier: orderIdentifier,
              initPaymentRequestParams: requestParams,
              initPaymentResponseBody: jsonDecode(response.body),
            ),
          );
        },
      );

  /// Повторное списание средств по сохранённой карте
  static DwTinkoffApiRequest<bool> charge({
    required String paymentId,
    required String rebillId,
  }) =>
      DwTinkoffApiRequest<bool>(
        method: DwTinkoffApiMethod.chargeRecurrent,
        params: {
          'PaymentId': paymentId,
          'RebillId': rebillId,
        },
        processResponse: _isOk,
      );
}
