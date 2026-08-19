import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartway_offline_flutter/src/network/connectivity_network_classifier.dart';
import 'package:dartway_offline_flutter/src/network/dw_network_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwConnectivityNetworkClassifier', () {
    const cases =
        <({List<ConnectivityResult> transports, DwNetworkClass want})>[
          (transports: [ConnectivityResult.none], want: DwNetworkClass.offline),
          (
            transports: [ConnectivityResult.mobile],
            want: DwNetworkClass.metered,
          ),
          (
            transports: [ConnectivityResult.wifi],
            want: DwNetworkClass.unmetered,
          ),
          (
            transports: [ConnectivityResult.ethernet],
            want: DwNetworkClass.unmetered,
          ),
          (transports: [], want: DwNetworkClass.unknown),
          (transports: [ConnectivityResult.vpn], want: DwNetworkClass.unknown),
          (
            transports: [ConnectivityResult.satellite],
            want: DwNetworkClass.unknown,
          ),
          (
            transports: [ConnectivityResult.wifi, ConnectivityResult.mobile],
            want: DwNetworkClass.unknown,
          ),
          (
            transports: [ConnectivityResult.none, ConnectivityResult.wifi],
            want: DwNetworkClass.offline,
          ),
        ];

    for (final testCase in cases) {
      test('${testCase.transports} maps to ${testCase.want}', () {
        expect(
          DwConnectivityNetworkClassifier.classify(testCase.transports),
          testCase.want,
        );
      });
    }
  });
}
