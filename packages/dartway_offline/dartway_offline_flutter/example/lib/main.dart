// The harness that puts dartway_offline_flutter through dart2js.
//
// The package is compiled for the web nowhere else in this repository: no
// example and no template depends on it, so an integer literal that JavaScript
// cannot hold exactly used to reach a consumer's release build before anything
// here objected. `flutter build web` on this app is that objection.
import 'package:dartway_offline_flutter/dartway_offline_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const _OfflineWebHarnessApp());

class _OfflineWebHarnessApp extends StatelessWidget {
  const _OfflineWebHarnessApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(child: Text('$DwOfflineConfig $DwDownloadJobState')),
    ),
  );
}
