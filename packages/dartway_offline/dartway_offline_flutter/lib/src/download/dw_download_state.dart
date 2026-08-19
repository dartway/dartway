import '../access/dw_offline_lease_policy.dart';

enum DwDownloadJobState {
  queued,
  waitingConsent,
  waitingNetwork,
  waitingDisk,
  waitingRetry,
  running,
  paused,
  activating,
  completed,
  failed,
  cancelled;

  static DwDownloadJobState fromStorage(String value) {
    return values.firstWhere(
      (state) => state.name == value,
      orElse: () => throw StateError('Unknown download job state: $value'),
    );
  }
}

enum DwDownloadTaskState {
  queued,
  enqueued,
  running,
  waitingRetry,
  waitingNetwork,
  waitingDisk,
  paused,
  publishing,
  completed,
  failed,
  cancelled;

  static DwDownloadTaskState fromStorage(String value) {
    return values.firstWhere(
      (state) => state.name == value,
      orElse: () => throw StateError('Unknown download task state: $value'),
    );
  }
}

final class DwOfflinePackageDownloadStatus {
  const DwOfflinePackageDownloadStatus({
    required this.userScopeId,
    required this.packageId,
    required this.jobId,
    required this.manifestRevision,
    required this.manifestDigest,
    required this.state,
    required this.bytesDownloaded,
    required this.bytesToDownload,
    required this.completedFileCount,
    required this.fileCount,
    required this.pauseReason,
    required this.lastErrorJson,
  });

  final String userScopeId;
  final String packageId;
  final String jobId;
  final String manifestRevision;
  final String manifestDigest;
  final DwDownloadJobState state;
  final int bytesDownloaded;
  final int bytesToDownload;
  final int completedFileCount;
  final int fileCount;
  final String? pauseReason;
  final String? lastErrorJson;

  double get progress {
    if (state == DwDownloadJobState.completed || bytesToDownload == 0) {
      return 1;
    }
    return (bytesDownloaded / bytesToDownload).clamp(0, 1).toDouble();
  }
}

final class DwDownloadTaskIdentity {
  const DwDownloadTaskIdentity({
    required this.userScopeId,
    required this.jobId,
    required this.assetId,
    required this.assetRevision,
  });

  final String userScopeId;
  final String jobId;
  final String assetId;
  final String assetRevision;
}

final class DwStoredDownloadActivation {
  const DwStoredDownloadActivation({
    required this.userScopeId,
    required this.jobId,
    required this.packageId,
    required this.manifestRevision,
    required this.manifestDigest,
  });

  final String userScopeId;
  final String jobId;
  final String packageId;
  final String manifestRevision;
  final String manifestDigest;
}

final class DwStoredDownloadTask {
  const DwStoredDownloadTask({
    required this.identity,
    required this.packageId,
    required this.manifestRevision,
    required this.manifestDigest,
    required this.priority,
    required this.packageTotalBytes,
    required this.consentedManifestDigest,
    required this.jobState,
    required this.taskState,
    required this.assetDescriptor,
    required this.nativeTaskId,
    required this.temporaryFilePath,
    required this.transferredBytes,
    required this.attemptCount,
    required this.nextEligibleAtEpochMs,
    required this.lastErrorJson,
    required this.createdAtEpochMs,
  });

  final DwDownloadTaskIdentity identity;
  final String packageId;
  final String manifestRevision;
  final String manifestDigest;
  final int priority;
  final int packageTotalBytes;
  final String? consentedManifestDigest;
  final DwDownloadJobState jobState;
  final DwDownloadTaskState taskState;
  final DwOfflineAssetDescriptor assetDescriptor;
  final String? nativeTaskId;
  final String? temporaryFilePath;
  final int transferredBytes;
  final int attemptCount;
  final int? nextEligibleAtEpochMs;
  final String? lastErrorJson;
  final int createdAtEpochMs;

  String get host => Uri.parse(assetDescriptor.downloadUrl).host;
}
