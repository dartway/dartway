import 'dart:convert';
import 'dart:io';

import 'package:dartway_serverpod_tinkoff_server/dartway_serverpod_tinkoff_server.dart';
import 'package:dartway_serverpod_tinkoff_server/src/domain/dw_tinkoff_payment_extension.dart';
import 'package:serverpod/serverpod.dart';

typedef DwOnPaymentProcessedCallback = Future<void> Function(
  Session session,
  DwTinkoffPayment payment,
  DwTinkoffPayment updatedPayment,
  DwTinkoffRegisteredCard? card,
);

typedef DwPaymentUpdatesFilter = Future<bool> Function(Session session,
    DwTinkoffPayment payment, DwTinkoffPaymentStatus newStatus);

/// Класс маршрута для обработки вебхуков от Тинькофф
class DwTinkoffWebhookRoute extends Route {
  DwTinkoffWebhookRoute({
    this.filter,
    required this.onConfirmed,
    this.onRefunded,
  });

  final DwPaymentUpdatesFilter? filter;

  final DwOnPaymentProcessedCallback onConfirmed;

  final DwOnPaymentProcessedCallback? onRefunded;

  @override
  Future<bool> handleCall(Session session, HttpRequest request) async {
    Map<String, dynamic>? body;
    bool paymentUpdated = false;

    Future<DwTinkoffRegisteredCard?> updateCard({
      required String tinkoffCustomerId,
    }) async {
      // Достаём карточные данные
      final cardId = body!['CardId']?.toString() ?? '';
      final rebillId = body['RebillId']?.toString() ?? '';
      final pan = body['Pan']?.toString() ?? '';

      if (cardId.isEmpty || rebillId.isEmpty || pan.isEmpty) {
        return null;
      }

      var card = await DwTinkoffRegisteredCard.db.findFirstRow(
        session,
        where: (t) =>
            t.tinkoffCardId.equals(cardId) &
            t.tinkoffCustomerId.equals(tinkoffCustomerId),
      );

      return card != null
          ? await session.db.updateRow(
              card.copyWith(rebillId: rebillId),
            )
          : await session.db.insertRow(
              DwTinkoffRegisteredCard(
                tinkoffCustomerId: tinkoffCustomerId,
                cardPan: pan,
                status: 'A',
                tinkoffCardId: cardId,
                rebillId: rebillId,
              ),
            );
    }

    /// Отвечает OK на запрос (обязательно "OK" в ответе — это требование Тинькофф)
    Future<bool> respond({
      String? error,
      String? errorDetails,
    }) async {
      try {
        print(
          '${error == null ? (paymentUpdated ? 'Success with' : 'Skipped') : 'Failed on'} Tinkoff webhook: ${error ?? 'payment ${body?['PaymentId']} ${body?['Status']}'}',
        );
        if (error != null) {
          print(errorDetails);
        }

        await DwTinkoffLog.db.insertRow(
          session,
          DwTinkoffLog(
            timestamp: DateTime.now(),
            logType: DwTinkoffLogType.webhook,
            paramsString: jsonEncode(body ?? {'error': 'invalid json'}),
            tinkoffCustomerId: body?['CustomerKey']?.toString(),
            paymentId: body?['PaymentId']?.toString(),
            paymentStatus: body?['Status']?.toString(),
            isOk: error == null,
            statusCode: null,
            error: error,
            errorDetails: errorDetails,
          ),
        );

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          error == null ? 'OK' : 'ERROR',
        ); // Важно: Тинькофф требует именно это
        await request.response.close();
      } catch (ex, st) {
        session.log(
          'Failed to respond to Tinkoff webhook',
          exception: ex,
          stackTrace: st,
        );
      } // Игнорируем ошибки при ответе
      return true;
    }

    try {
      if (request.method != 'POST') return false; // Только POST

      // Парсим JSON тело
      body = json.decode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;

      // Ищем оплату по PaymentId
      final payment = await DwTinkoffPayment.db.findFirstRow(
        session,
        where: (t) => t.tinkoffPaymentId.equals(body!['PaymentId']!.toString()),
      );

      if (payment == null) {
        throw Exception(
          'Payment with ID ${body['PaymentId']} not found',
        );
      }

      if (filter != null &&
          false ==
              await filter!(
                session,
                payment,
                DwTinkoffPaymentExtension.paymentStatusFromTinkoffRawStatus(
                  body['Status'],
                ),
              )) {
        // Если фильтр не пропускает обновление, просто отвечаем OK
        return respond();
      }

      // Обновляем оплату по данным из вебхука
      final updatedPayment = await session.db.updateRow(
        payment.updateFromWebhook(webhookJsonBody: body),
      );
      paymentUpdated = true;
// Обновляем или создаём зарегистрированную карту
      final updatedCard = await updateCard(
        tinkoffCustomerId: payment.tinkoffCustomerId,
      );

      if (updatedPayment.tinkoffStatus == DwTinkoffPaymentStatus.confirmed) {
        // Вызываем кастомную обработку подтверждённой оплаты
        await onConfirmed.call(
          session,
          payment,
          updatedPayment,
          updatedCard,
        );
      } else if (onRefunded != null &&
          updatedPayment.tinkoffStatus == DwTinkoffPaymentStatus.refunded) {
        // Если оплата была возвращена, то удаляем карту
        await onRefunded!.call(
          session,
          payment,
          updatedPayment,
          updatedCard,
        );
      }

      return respond();
    } catch (e, st) {
      return respond(
        error: e.toString(),
        errorDetails: st.toString(),
      );
    }
  }
}
