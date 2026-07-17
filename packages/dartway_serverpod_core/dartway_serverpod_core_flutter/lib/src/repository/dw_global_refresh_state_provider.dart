import 'package:flutter_riverpod/flutter_riverpod.dart';

final dwGlobalRefreshStateProvider =
    NotifierProvider<DwGlobalRefreshStateNotifier, DateTime>(
      DwGlobalRefreshStateNotifier.new,
    );

class DwGlobalRefreshStateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void refresh() {
    state = DateTime.now();
  }
}
