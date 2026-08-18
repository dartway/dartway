import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import 'dw_background_download_transport.dart';

final class DwBackgroundDownloaderTransport
    implements DwBackgroundDownloadTransport {
  DwBackgroundDownloaderTransport({FileDownloader? downloader})
    : _downloader = downloader ?? FileDownloader();

  static const String taskGroup = 'dartway_offline';
  static const String taskDirectory = 'dartway_offline_downloads';

  final FileDownloader _downloader;
  final StreamController<DwBackgroundDownloadUpdate> _updatesController =
      StreamController.broadcast();
  StreamSubscription<TaskUpdate>? _pluginUpdatesSubscription;
  bool _isInitialized = false;

  @override
  Stream<DwBackgroundDownloadUpdate> get updates => _updatesController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _downloader.ready;
    _pluginUpdatesSubscription = _downloader.updates.listen((update) async {
      try {
        _updatesController.add(await mapPluginUpdate(update));
      } on Object catch (error, stackTrace) {
        _updatesController.addError(error, stackTrace);
      }
    }, onError: _updatesController.addError);
    await _downloader.trackTasks(markDownloadedComplete: true);
    await _downloader.resumeFromBackground();
    await _downloader.rescheduleKilledTasks();
    _isInitialized = true;
  }

  @override
  Future<bool> enqueue(DwBackgroundDownloadRequest request) {
    return _downloader.enqueue(createPluginTask(request));
  }

  @override
  Future<bool> pause(String taskId) async {
    final task = await _downloader.taskForId(taskId);
    if (task is! DownloadTask) return false;
    return _downloader.pause(task);
  }

  @override
  Future<bool> resume(String taskId) async {
    final task = await _downloader.taskForId(taskId);
    if (task is! DownloadTask) return false;
    return _downloader.resume(task);
  }

  @override
  Future<bool> cancel(String taskId) => _downloader.cancelTaskWithId(taskId);

  @override
  Future<Set<String>> activeTaskIds() async {
    return (await _downloader.allTasks(allGroups: true))
        .where((task) => task.group == taskGroup)
        .map((task) => task.taskId)
        .toSet();
  }

  @override
  Future<void> dispose() async {
    await _pluginUpdatesSubscription?.cancel();
    await _updatesController.close();
  }

  static DownloadTask createPluginTask(
    DwBackgroundDownloadRequest request, {
    bool attachNativePreflight = true,
  }) {
    final uri = Uri.tryParse(request.url);
    if (request.taskId.isEmpty ||
        request.taskId.contains('/') ||
        request.taskId.contains(r'\') ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        !DwBackgroundDownloadPreflight.isValidDnsHost(uri.host) ||
        !request.allowedRedirectHosts.contains(uri.host)) {
      throw ArgumentError('Native download request is invalid.');
    }
    if (request.priority < 0) {
      throw ArgumentError.value(
        request.priority,
        'priority',
        'must not be negative',
      );
    }
    if (request.expectedSizeBytes < 0 ||
        request.allowedRedirectHosts.any(
          (host) => !DwBackgroundDownloadPreflight.isValidDnsHost(host),
        )) {
      throw ArgumentError('Native download policy is invalid.');
    }
    final allowedRedirectHosts = [...request.allowedRedirectHosts]..sort();
    final pluginPriority = 10 - request.priority.clamp(0, 10);
    return DownloadTask(
      taskId: request.taskId,
      url: request.url,
      filename: '${request.taskId}.download',
      directory: taskDirectory,
      baseDirectory: BaseDirectory.applicationSupport,
      group: taskGroup,
      updates: Updates.statusAndProgress,
      requiresWiFi: false,
      retries: 0,
      allowPause: true,
      priority: pluginPriority,
      metaData: jsonEncode({
        'allowedRedirectHosts': allowedRedirectHosts,
        'expectedSizeBytes': request.expectedSizeBytes,
        'schemaVersion': 1,
      }),
      options: attachNativePreflight
          ? TaskOptions(onTaskStart: DwBackgroundDownloadPreflight.onTaskStart)
          : null,
    );
  }

  static DwNativeDownloadFailureKind failureKindFor(TaskException? exception) {
    return switch (exception) {
      TaskHttpException(httpResponseCode: 401) =>
        DwNativeDownloadFailureKind.unauthorized,
      TaskHttpException(httpResponseCode: 403) =>
        DwNativeDownloadFailureKind.forbidden,
      TaskHttpException(httpResponseCode: 404) =>
        DwNativeDownloadFailureKind.notFound,
      TaskHttpException() => DwNativeDownloadFailureKind.http,
      TaskConnectionException() ||
      TaskResumeException() => DwNativeDownloadFailureKind.connection,
      TaskUrlException() => DwNativeDownloadFailureKind.invalidUrl,
      TaskFileSystemException() => DwNativeDownloadFailureKind.fileSystem,
      _ => DwNativeDownloadFailureKind.other,
    };
  }

  static Future<DwBackgroundDownloadUpdate> mapPluginUpdate(
    TaskUpdate update,
  ) async {
    if (update case TaskProgressUpdate(
      :final task,
      :final progress,
      :final expectedFileSize,
    )) {
      return DwBackgroundDownloadUpdate(
        taskId: task.taskId,
        status: DwNativeDownloadStatus.running,
        progress: progress,
        expectedFileSizeBytes: expectedFileSize >= 0 ? expectedFileSize : null,
      );
    }
    final statusUpdate = update as TaskStatusUpdate;
    final rejectedByPreflight = DwBackgroundDownloadPreflight.isRejectedUrl(
      statusUpdate.task.url,
    );
    final status = switch (statusUpdate.status) {
      TaskStatus.enqueued => DwNativeDownloadStatus.enqueued,
      TaskStatus.running => DwNativeDownloadStatus.running,
      TaskStatus.waitingToRetry => DwNativeDownloadStatus.waitingToRetry,
      TaskStatus.paused => DwNativeDownloadStatus.paused,
      TaskStatus.complete => DwNativeDownloadStatus.complete,
      TaskStatus.notFound => DwNativeDownloadStatus.notFound,
      TaskStatus.failed => DwNativeDownloadStatus.failed,
      TaskStatus.canceled => DwNativeDownloadStatus.canceled,
    };
    return DwBackgroundDownloadUpdate(
      taskId: statusUpdate.task.taskId,
      status: status,
      expectedFileSizeBytes: _reportedResponseSize(
        statusUpdate.responseHeaders,
        statusUpdate.responseStatusCode,
      ),
      completedFilePath: status == DwNativeDownloadStatus.complete
          ? await statusUpdate.task.filePath()
          : null,
      failureKind: status == DwNativeDownloadStatus.notFound
          ? DwNativeDownloadFailureKind.notFound
          : status == DwNativeDownloadStatus.failed
          ? rejectedByPreflight
                ? DwNativeDownloadFailureKind.invalidUrl
                : failureKindFor(statusUpdate.exception)
          : null,
      responseStatusCode: statusUpdate.responseStatusCode,
      errorDescription: statusUpdate.exception?.description,
    );
  }

  static int? _reportedResponseSize(
    Map<String, String>? responseHeaders,
    int? responseStatusCode,
  ) {
    if (responseHeaders == null) return null;
    final contentRange = responseHeaders['content-range'];
    if (contentRange != null) {
      final totalMatch = RegExp(r'/([0-9]+)$').firstMatch(contentRange.trim());
      final totalBytes = int.tryParse(totalMatch?.group(1) ?? '');
      if (totalBytes != null && totalBytes >= 0) return totalBytes;
    }
    if (responseStatusCode == HttpStatus.partialContent) return null;
    final contentLength = int.tryParse(
      responseHeaders['content-length']?.trim() ?? '',
    );
    return contentLength != null && contentLength >= 0 ? contentLength : null;
  }
}

/// Resolves and validates redirects before handing a URL to the native task.
@pragma('vm:entry-point')
abstract final class DwBackgroundDownloadPreflight {
  static const int maximumRedirectHops = 5;
  static final Uri _rejectedUrl = Uri.parse(
    'https://dartway-offline.invalid/rejected',
  );

  @pragma('vm:entry-point')
  static Future<Task?> onTaskStart(Task originalTask) async {
    if (originalTask is! DownloadTask) return originalTask;
    try {
      final metadata = jsonDecode(originalTask.metaData);
      if (metadata is! Map<String, dynamic> ||
          metadata['schemaVersion'] != 1 ||
          metadata['expectedSizeBytes'] is! int ||
          metadata['allowedRedirectHosts'] is! List<Object?>) {
        return originalTask.copyWith(url: _rejectedUrl.toString());
      }
      final redirectHosts = (metadata['allowedRedirectHosts']! as List<Object?>)
          .whereType<String>()
          .toSet();
      if (redirectHosts.length !=
          (metadata['allowedRedirectHosts']! as List<Object?>).length) {
        return originalTask.copyWith(url: _rejectedUrl.toString());
      }
      final resolvedUrl = await _resolve(
        Uri.parse(originalTask.url),
        allowedRedirectHosts: redirectHosts,
        expectedSizeBytes: metadata['expectedSizeBytes']! as int,
      );
      return originalTask.copyWith(url: resolvedUrl.toString());
    } on Object {
      return originalTask.copyWith(url: _rejectedUrl.toString());
    }
  }

  static Uri? isAllowedRedirect({
    required Uri currentUrl,
    required String location,
    required Set<String> allowedRedirectHosts,
    required int redirectHop,
  }) {
    if (redirectHop < 1 || redirectHop > maximumRedirectHops) return null;
    final redirectUrl = currentUrl.resolve(location);
    if (redirectUrl.scheme != 'https' ||
        redirectUrl.userInfo.isNotEmpty ||
        redirectUrl.hasPort ||
        redirectUrl.hasFragment ||
        !isValidDnsHost(redirectUrl.host) ||
        !allowedRedirectHosts.contains(redirectUrl.host)) {
      return null;
    }
    return redirectUrl;
  }

  static bool isValidDnsHost(String value) {
    if (value.isEmpty || value != value.toLowerCase() || value.length > 253) {
      return false;
    }
    return value
        .split('.')
        .every(
          (label) =>
              label.isNotEmpty &&
              label.length <= 63 &&
              RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
        );
  }

  static bool isRejectedUrl(String encodedUrl) {
    return encodedUrl == _rejectedUrl.toString();
  }

  static Future<Uri> _resolve(
    Uri initialUrl, {
    required Set<String> allowedRedirectHosts,
    required int expectedSizeBytes,
  }) async {
    if (expectedSizeBytes < 0 ||
        initialUrl.scheme != 'https' ||
        initialUrl.userInfo.isNotEmpty ||
        initialUrl.hasPort ||
        initialUrl.hasFragment ||
        !isValidDnsHost(initialUrl.host) ||
        !allowedRedirectHosts.contains(initialUrl.host)) {
      throw const FormatException();
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      var currentUrl = initialUrl;
      for (var redirectHop = 0; ; redirectHop++) {
        final request = await client.headUrl(currentUrl);
        request.followRedirects = false;
        final response = await request.close();
        try {
          if (response.isRedirect) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null) throw const FormatException();
            final redirectUrl = isAllowedRedirect(
              currentUrl: currentUrl,
              location: location,
              allowedRedirectHosts: allowedRedirectHosts,
              redirectHop: redirectHop + 1,
            );
            if (redirectUrl == null) throw const FormatException();
            currentUrl = redirectUrl;
            continue;
          }
          if (response.statusCode < HttpStatus.ok ||
              response.statusCode >= HttpStatus.multipleChoices ||
              response.contentLength != expectedSizeBytes) {
            throw const FormatException();
          }
          return currentUrl;
        } finally {
          await response.drain<void>();
        }
      }
    } finally {
      client.close(force: true);
    }
  }
}
