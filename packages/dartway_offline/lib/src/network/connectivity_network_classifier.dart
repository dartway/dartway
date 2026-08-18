import 'package:connectivity_plus/connectivity_plus.dart';

import 'dw_network_class.dart';

final class DwConnectivityNetworkClassifier implements DwNetworkClassSource {
  DwConnectivityNetworkClassifier({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static DwNetworkClass classify(Iterable<ConnectivityResult> transports) {
    final distinctTransports = transports.toSet();
    if (distinctTransports.contains(ConnectivityResult.none)) {
      return DwNetworkClass.offline;
    }
    if (distinctTransports.length != 1) {
      return DwNetworkClass.unknown;
    }
    return switch (distinctTransports.single) {
      ConnectivityResult.mobile => DwNetworkClass.metered,
      ConnectivityResult.wifi ||
      ConnectivityResult.ethernet => DwNetworkClass.unmetered,
      ConnectivityResult.none => DwNetworkClass.offline,
      ConnectivityResult.bluetooth ||
      ConnectivityResult.vpn ||
      ConnectivityResult.satellite ||
      ConnectivityResult.other => DwNetworkClass.unknown,
    };
  }

  @override
  Future<DwNetworkClass> currentNetworkClass() async {
    return classify(await _connectivity.checkConnectivity());
  }

  @override
  Stream<DwNetworkClass> get networkClassChanges =>
      _connectivity.onConnectivityChanged.map(classify).distinct();
}
