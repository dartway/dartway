// A hand-written stand-in for the part of `dartway_serverpod_core_flutter` the
// skeleton-defaults fixture is written against: the `dw` root, its `repo`
// facade, the `mockModelId` sentinel and `setupRepository`.
//
// Stubbed rather than depended on, because the rule matches the sentinel by
// name and nothing else — see `ModelRebuildByConstructorRule`. Pulling the real
// core in would drag riverpod, the serverpod client half and four workspace
// packages into a fixture that resolves standalone, and would still prove the
// same thing: that a construction whose `id:` reads `dw.repo.mockModelId` is
// left alone.

import 'package:serverpod_client/serverpod_client.dart';

class DwRepo {
  const DwRepo();

  /// Placeholder id for the instance a list skeleton is shaped from.
  int get mockModelId => 0;

  void setupRepository<T extends SerializableModel>({required T defaultModel}) {
    // The real one registers the instance; the fixture only has to compile.
  }
}

class DwCore {
  const DwCore();

  DwRepo get repo => const DwRepo();
}

const dw = DwCore();

/// The static `dw.repo.mockModelId` delegates to. Not exported by the framework
/// — it is here because the rule accepts either spelling, and a fixture is
/// where that is worth stating.
class DwRepository {
  static const int mockModelId = 0;
}
