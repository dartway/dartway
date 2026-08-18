enum DwNetworkClass { offline, metered, unmetered, unknown }

abstract interface class DwNetworkClassSource {
  Future<DwNetworkClass> currentNetworkClass();

  Stream<DwNetworkClass> get networkClassChanges;
}
