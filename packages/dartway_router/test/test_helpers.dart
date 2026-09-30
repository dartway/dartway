import 'package:dartway_router/dartway_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';

/// Builds a router the way an app does — inside a provider, with its `ref`,
/// and kept watched the way `MaterialApp.router` watches it — in [container],
/// or in a fresh one disposed when the test ends.
///
/// A failure to assemble is rethrown as the router threw it, not wrapped in
/// Riverpod's [ProviderException].
DwAppRouter<S> buildRouter<S>(
  DwAppRouter<S> Function(Ref ref) build, {
  ProviderContainer? container,
}) {
  final scope = container ?? _container();
  try {
    return scope.listen(Provider<DwAppRouter<S>>(build), (_, _) {}).read();
  } on ProviderException catch (e) {
    Error.throwWithStackTrace(e.exception, e.stackTrace);
  }
}

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}
