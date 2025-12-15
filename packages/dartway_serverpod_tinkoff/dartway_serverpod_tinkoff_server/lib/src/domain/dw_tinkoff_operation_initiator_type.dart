/// Тип инициатора операции (CIT/MIT), передаваемый в параметре `Initiator` при инициализации платежа.
///
/// Используется для указания сценария, в котором выполняется платёж:
/// - сохраняются ли реквизиты карты
/// - используется ли RebillId
/// - инициирует ли платёж покупатель или мерчант
enum DwTinkoffOperationInitiatorType {
  /// CIT CNC – Инициированная покупателем оплата без сохранения реквизитов карты.
  standard('0', false),

  /// CIT CC – Инициированная покупателем оплата с сохранением реквизитов карты.
  withCredentialsCapture('1', true),

  /// CIT CO – Оплата по ранее сохранённым реквизитам карты (CIT CC).
  recurringByCustomer('2', false),

  /// MIT COF R – Периодические платежи без графика (инициированы мерчантом).
  recurringByMerchant('R', false),

  /// MIT COF I – Периодические платежи по графику (инициированы мерчантом).
  recurringRegular('I', false);

  const DwTinkoffOperationInitiatorType(this.apiValue, this.requestRebillId);

  /// Значение, которое должно быть передано в параметре `Initiator` API Тинькофф.
  final String apiValue;

  /// Требуется ли наличие `RebillId` при использовании данного типа операции.
  final bool requestRebillId;
}
