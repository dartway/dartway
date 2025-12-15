import 'package:dartway_serverpod_tinkoff_server/src/generated/protocol.dart';

/// Расширение для получения информации о методе API Тинькофф
extension DwTinkoffApiMethodExtension on DwTinkoffApiMethod {
  /// Полный путь к REST endpoint-у Тинькофф, соответствующему данному методу
  ///
  /// Используется при отправке запросов через TinkoffApiService.
  String get endpoint => switch (this) {
        DwTinkoffApiMethod.getCustomer => '/v2/GetCustomer',
        DwTinkoffApiMethod.addCustomer => '/v2/AddCustomer',
        DwTinkoffApiMethod.initPayment => '/v2/Init',
        DwTinkoffApiMethod.cancelPayment => '/v2/Cancel',
        DwTinkoffApiMethod.chargeRecurrent => '/v2/Charge',
      };

  /// Человеко-читаемое название метода, используется в логах или интерфейсах
  ///
  /// Например, в админке, журнале операций или системе аудита.
  String get label => switch (this) {
        DwTinkoffApiMethod.getCustomer => 'Get Customer',
        DwTinkoffApiMethod.addCustomer => 'Add Customer',
        DwTinkoffApiMethod.initPayment => 'Init Payment',
        DwTinkoffApiMethod.cancelPayment => 'Cancel Payment',
        DwTinkoffApiMethod.chargeRecurrent => 'Charge Recurrent',
      };
}
