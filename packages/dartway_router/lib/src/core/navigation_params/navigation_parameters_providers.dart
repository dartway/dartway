import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_parameters_providers.g.dart';

@Riverpod(keepAlive: true, dependencies: [])
Map<String, String> navigationPathParameters(Ref ref) {
  return const {};
}

@Riverpod(keepAlive: true, dependencies: [])
Object? navigationExtraParameter(Ref ref) {
  return null;
}
