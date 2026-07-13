part of '../dw.dart';

class _DwServices {
  _DwServices._();

  late DwSharedPreferences _prefs;
  DwSharedPreferences get sharedPreferences => _prefs;

  Future<void> _init({required DwConfig config}) async {
    if (config.useSharedPreferences) {
      _prefs = DwSharedPreferences(await SharedPreferences.getInstance());
    }
  }
}
