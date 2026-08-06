// The over-eager half of the fixture: a test builds its own root scope with
// overrides, and that is the sanctioned way to swap a provider for a fake. Not
// a single lint may fire in this file — custom_lint fails on an unexpected
// report exactly as it does on a missing one.
//
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dartway_lints_example/app/forbidden_provider_scope.dart';

Widget buildTestableApp() {
  return ProviderScope(
    overrides: [greetingProvider.overrideWithValue('fake')],
    child: const SizedBox.shrink(),
  );
}
