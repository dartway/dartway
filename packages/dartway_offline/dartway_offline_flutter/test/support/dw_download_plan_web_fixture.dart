import 'package:dartway_offline_flutter/src/download/dw_download_plan.dart';

void main() {
  final downloadPlan = DwDownloadPackagePlan(
    userScopeId: 'scope-a',
    packageId: 'package-a',
    manifestRevision: 'manifest-a',
    manifestDigest: 'digest-a',
    priority: 0,
    assets: [
      DwDownloadAssetPlan(
        assetId: 'asset-a',
        assetRevision: 'revision-a',
        expectedSizeBytes: 1,
      ),
    ],
  );
  if (!downloadPlan.jobId.startsWith('dw_')) {
    throw StateError('Download plan did not create a stable job id.');
  }
}
