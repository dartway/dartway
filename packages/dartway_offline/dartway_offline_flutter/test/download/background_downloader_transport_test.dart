import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:dartway_offline_flutter/src/download/background_downloader_transport.dart';
import 'package:dartway_offline_flutter/src/download/dw_background_download_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwBackgroundDownloaderTransport', () {
    test('creates an app-support task with plugin retries disabled', () {
      final task = DwBackgroundDownloaderTransport.createPluginTask(
        const DwBackgroundDownloadRequest(
          taskId: 'native-task',
          url: 'https://cdn.example.test/video.mp4',
          priority: 8,
          allowedRedirectHosts: ['cdn.example.test', 'media.example.test'],
          expectedSizeBytes: 4096,
        ),
        attachNativePreflight: false,
      );

      expect(task.taskId, 'native-task');
      expect(task.baseDirectory, BaseDirectory.applicationSupport);
      expect(task.directory, 'dartway_offline_downloads');
      expect(task.filename, 'native-task.download');
      expect(task.group, 'dartway_offline');
      expect(task.updates, Updates.statusAndProgress);
      expect(task.retries, 0);
      expect(task.allowPause, isTrue);
      expect(task.requiresWiFi, isFalse);
      expect(task.priority, 2);
      expect(task.options, isNull);
      expect(jsonDecode(task.metaData), {
        'allowedRedirectHosts': ['cdn.example.test', 'media.example.test'],
        'expectedSizeBytes': 4096,
        'schemaVersion': 1,
      });
    });

    test('rejects non-HTTPS download requests before native enqueue', () {
      expect(
        () => DwBackgroundDownloaderTransport.createPluginTask(
          const DwBackgroundDownloadRequest(
            taskId: 'native-task',
            url: 'http://cdn.example.test/video.mp4',
            priority: 0,
            allowedRedirectHosts: ['cdn.example.test'],
            expectedSizeBytes: 1,
          ),
          attachNativePreflight: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an initial host outside the signed host set', () {
      expect(
        () => DwBackgroundDownloaderTransport.createPluginTask(
          const DwBackgroundDownloadRequest(
            taskId: 'native-task',
            url: 'https://untrusted.example.test/video.mp4',
            priority: 0,
            allowedRedirectHosts: ['cdn.example.test'],
            expectedSizeBytes: 1,
          ),
          attachNativePreflight: false,
        ),
        throwsArgumentError,
      );
    });

    test('preflight only accepts signed HTTPS redirect hosts', () {
      expect(
        DwBackgroundDownloadPreflight.isAllowedRedirect(
          currentUrl: Uri.parse('https://cdn.example.test/video.mp4'),
          location: '/moved.mp4',
          allowedRedirectHosts: const {'cdn.example.test'},
          redirectHop: 1,
        ),
        Uri.parse('https://cdn.example.test/moved.mp4'),
      );
      expect(
        DwBackgroundDownloadPreflight.isAllowedRedirect(
          currentUrl: Uri.parse('https://cdn.example.test/video.mp4'),
          location: 'https://evil.example.test/video.mp4',
          allowedRedirectHosts: const {'cdn.example.test'},
          redirectHop: 1,
        ),
        isNull,
      );
    });

    test('maps HTTP and plugin failures without parsing localized text', () {
      expect(
        DwBackgroundDownloaderTransport.failureKindFor(
          TaskHttpException('unauthorized', 401),
        ),
        DwNativeDownloadFailureKind.unauthorized,
      );
      expect(
        DwBackgroundDownloaderTransport.failureKindFor(
          TaskHttpException('forbidden', 403),
        ),
        DwNativeDownloadFailureKind.forbidden,
      );
      expect(
        DwBackgroundDownloaderTransport.failureKindFor(
          TaskConnectionException('localized message'),
        ),
        DwNativeDownloadFailureKind.connection,
      );
      expect(
        DwBackgroundDownloaderTransport.failureKindFor(
          TaskUrlException('localized message'),
        ),
        DwNativeDownloadFailureKind.invalidUrl,
      );
      expect(
        DwBackgroundDownloaderTransport.failureKindFor(
          TaskFileSystemException('localized message'),
        ),
        DwNativeDownloadFailureKind.fileSystem,
      );
    });

    test(
      'maps a rejected preflight URL as invalid instead of disk failure',
      () async {
        final originalTask = DownloadTask(
          taskId: 'native-task',
          url: 'https://cdn.example.test/video.mp4',
          metaData: '{}',
        );
        final rejectedTask = await DwBackgroundDownloadPreflight.onTaskStart(
          originalTask,
        );

        final update = await DwBackgroundDownloaderTransport.mapPluginUpdate(
          TaskStatusUpdate(
            rejectedTask!,
            TaskStatus.failed,
            TaskFileSystemException('localized native failure'),
          ),
        );

        expect(update.failureKind, DwNativeDownloadFailureKind.invalidUrl);
      },
    );

    test(
      'maps the native GET content length into the transport update',
      () async {
        final task = DwBackgroundDownloaderTransport.createPluginTask(
          const DwBackgroundDownloadRequest(
            taskId: 'native-task',
            url: 'https://cdn.example.test/video.mp4',
            priority: 0,
            allowedRedirectHosts: ['cdn.example.test'],
            expectedSizeBytes: 4096,
          ),
          attachNativePreflight: false,
        );

        final update = await DwBackgroundDownloaderTransport.mapPluginUpdate(
          TaskStatusUpdate(
            task,
            TaskStatus.failed,
            TaskHttpException('server error', 500),
            null,
            const {'content-length': '8192'},
            500,
          ),
        );

        expect(update.expectedFileSizeBytes, 8192);
      },
    );
  });
}
