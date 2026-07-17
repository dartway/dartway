import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class DwInfiniteListViewConfig<Entity> {
  AsyncValue<List<Entity>> watchAsyncValue(WidgetRef ref);

  Future<bool> loadNextPage(WidgetRef ref);
}
