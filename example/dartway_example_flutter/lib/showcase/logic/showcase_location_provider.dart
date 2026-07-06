import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/router/router.dart';

part 'showcase_location_provider.g.dart';

/// Current app location observed from OUTSIDE the router widget tree
/// (the shell lives in MaterialApp.builder where GoRouterState.of is not
/// available), so we listen to the router delegate directly.
@riverpod
class ShowcaseLocation extends _$ShowcaseLocation {
  @override
  String build() {
    final delegate = ref.watch(appRouterProvider).router.routerDelegate;

    void syncLocation() {
      final configuration = delegate.currentConfiguration;
      if (configuration.isNotEmpty) {
        state = configuration.uri.path;
      }
    }

    delegate.addListener(syncLocation);
    ref.onDispose(() => delegate.removeListener(syncLocation));

    final configuration = delegate.currentConfiguration;
    return configuration.isEmpty ? '/' : configuration.uri.path;
  }
}
