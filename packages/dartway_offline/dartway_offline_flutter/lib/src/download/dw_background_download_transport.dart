enum DwNativeDownloadStatus {
  enqueued,
  running,
  waitingToRetry,
  paused,
  complete,
  notFound,
  failed,
  canceled,
}

enum DwNativeDownloadFailureKind {
  connection,
  unauthorized,
  forbidden,
  notFound,
  invalidUrl,
  fileSystem,
  http,
  other,
}

final class DwBackgroundDownloadRequest {
  const DwBackgroundDownloadRequest({
    required this.taskId,
    required this.url,
    required this.priority,
    required this.allowedRedirectHosts,
    required this.expectedSizeBytes,
  });

  final String taskId;
  final String url;
  final int priority;
  final List<String> allowedRedirectHosts;
  final int expectedSizeBytes;
}

final class DwBackgroundDownloadUpdate {
  const DwBackgroundDownloadUpdate({
    required this.taskId,
    required this.status,
    this.progress,
    this.expectedFileSizeBytes,
    this.completedFilePath,
    this.failureKind,
    this.responseStatusCode,
    this.errorDescription,
  });

  final String taskId;
  final DwNativeDownloadStatus status;
  final double? progress;
  final int? expectedFileSizeBytes;
  final String? completedFilePath;
  final DwNativeDownloadFailureKind? failureKind;
  final int? responseStatusCode;
  final String? errorDescription;
}

abstract interface class DwBackgroundDownloadTransport {
  Stream<DwBackgroundDownloadUpdate> get updates;

  Future<void> initialize();

  Future<bool> enqueue(DwBackgroundDownloadRequest request);

  Future<bool> pause(String taskId);

  Future<bool> resume(String taskId);

  Future<bool> cancel(String taskId);

  Future<Set<String>> activeTaskIds();

  Future<void> dispose();
}
