import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/foundation.dart';

/// Where one upload stands, for a widget to render.
sealed class DwUploadState {
  const DwUploadState();
}

/// Nothing is being uploaded: before the first upload, or after `reset`.
final class DwUploadIdle extends DwUploadState {
  const DwUploadIdle();

  @override
  bool operator ==(Object other) => other is DwUploadIdle;

  @override
  int get hashCode => (DwUploadIdle).hashCode;

  @override
  String toString() => 'DwUploadIdle()';
}

/// Uploading: [sentBytes] of [totalBytes] have gone. Starts at zero while the
/// ticket is asked for, and stays at the total while the server confirms.
final class DwUploadProgress extends DwUploadState {
  const DwUploadProgress(this.sentBytes, this.totalBytes);

  final int sentBytes;
  final int totalBytes;

  /// From 0 to 1, for a progress bar.
  double get fraction => totalBytes == 0 ? 1 : sentBytes / totalBytes;

  @override
  bool operator ==(Object other) =>
      other is DwUploadProgress &&
      other.sentBytes == sentBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(sentBytes, totalBytes);

  @override
  String toString() => 'DwUploadProgress($sentBytes/$totalBytes)';
}

/// Uploaded and confirmed: [file] is what a project command references by
/// id.
final class DwUploadDone extends DwUploadState {
  const DwUploadDone(this.file);

  final DwStoredFile file;

  @override
  bool operator ==(Object other) => other is DwUploadDone && other.file == file;

  @override
  int get hashCode => file.hashCode;

  @override
  String toString() => 'DwUploadDone($file)';
}

/// The upload ended without a file. [error] is typed as every data error of
/// the framework is: [DwRefusalException] (the server said no — render its
/// refusal through the app's catalogue), [DwNotAuthenticatedException],
/// [DwFailedException], [DwTimeoutException], or [DwUploadException] (the
/// bytes did not reach storage).
final class DwUploadError extends DwUploadState {
  const DwUploadError(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;

  /// The refusal, when the server refused.
  DwCallRefusal? get refusal => switch (error) {
    DwRefusalException(:final refusal) => refusal,
    _ => null,
  };

  @override
  String toString() => 'DwUploadError($error)';
}

/// One upload slot of a screen — an avatar picker, an attachment button: its
/// [DwUploadState] as a [ValueListenable], so a `ValueListenableBuilder`
/// renders progress, the error and the result without further wiring.
///
/// ```dart
/// final avatar = dw.uploader();              // in State.initState
/// final file = await avatar.upload(
///   AppUpload.avatar,
///   DwUploadSource.bytes(picked),
///   fileName: name,
///   contentType: 'image/jpeg',
/// );
/// if (file != null) await dw.command(SetAvatar(fileId: file.id));
/// avatar.dispose();                          // in State.dispose
/// ```
///
/// Picking the file is the app's: the framework carries no picker plugin.
class DwUploadNotifier extends ValueNotifier<DwUploadState> {
  /// [onError] receives what is worth an operator's attention — a server
  /// failure, storage refusing an upload (a misconfigured bucket) or an
  /// unexpected error — never a refusal, a signed-out caller or a network
  /// that is down; `dw.uploader()` connects it to the app's error reporting.
  DwUploadNotifier(this.files, {this.onError}) : super(const DwUploadIdle());

  final DwFileClient files;
  final void Function(Object error, StackTrace stackTrace)? onError;

  bool _disposed = false;

  /// Whether an upload is running; another one is refused meanwhile.
  bool get isBusy => value is DwUploadProgress;

  /// Completed by [cancel] to stop the running upload.
  Completer<void>? _cancel;

  /// Uploads [source] and answers the file, or `null` when the upload ended
  /// in [DwUploadError] — the state says why. Throws [StateError] while
  /// another upload of this notifier runs.
  Future<DwStoredFile?> upload(
    DwUploadPurpose purpose,
    DwUploadSource source, {
    required String fileName,
    required String contentType,
  }) async {
    if (isBusy) {
      throw StateError('This DwUploadNotifier is already uploading.');
    }
    _set(DwUploadProgress(0, source.byteSize));
    final cancel = _cancel = Completer<void>();
    try {
      final result = await files.upload(
        purpose,
        source,
        fileName: fileName,
        contentType: contentType,
        onProgress: (sent, total) => _set(DwUploadProgress(sent, total)),
        cancel: cancel.future,
      );
      switch (result) {
        case DwCallOk(:final value):
          _set(DwUploadDone(value));
          return value;
        case DwCallRefused(:final refusal):
          _set(DwUploadError(DwRefusalException(refusal)));
        case DwNotAuthenticated():
          _set(const DwUploadError(DwNotAuthenticatedException()));
        case DwCallFailed(:final incidentId):
          final error = DwFailedException(incidentId);
          final stackTrace = StackTrace.current;
          _set(DwUploadError(error, stackTrace));
          onError?.call(error, stackTrace);
      }
    } on DwUploadCancelledException {
      // Asked for: back to idle, with nothing to report.
      _set(const DwUploadIdle());
    } catch (error, stackTrace) {
      _set(DwUploadError(error, stackTrace));
      final expected = switch (error) {
        DwUploadException(failure: DwUploadFailure.rejected) => false,
        DwUploadException() ||
        DwTimeoutException() ||
        DwClientStoppedException() => true,
        _ => false,
      };
      if (!expected) onError?.call(error, stackTrace);
    } finally {
      _cancel = null;
    }
    return null;
  }

  /// Stops the running upload: the transfer is aborted, nothing is confirmed,
  /// [upload] answers `null` and the state goes back to [DwUploadIdle]. The
  /// ticket stays unfinished, and the server's cleanup removes it with
  /// whatever bytes arrived — so a user who changes their mind does not leave
  /// a gigabyte in the bucket (#284). Does nothing when no upload runs, or
  /// once the upload is being confirmed and the file is already theirs.
  ///
  /// [dispose] does not cancel: an upload still running when the screen goes
  /// away finishes, and whoever awaits [upload] gets the file. A screen that
  /// wants its upload gone with it calls [cancel] first.
  void cancel() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  /// Back to [DwUploadIdle] — after the result was used, or to dismiss an
  /// error. Throws [StateError] while an upload runs.
  void reset() {
    if (isBusy) {
      throw StateError('A running upload cannot be reset.');
    }
    _set(const DwUploadIdle());
  }

  /// An upload still running when the screen goes away finishes on its own;
  /// its states are no longer published.
  void _set(DwUploadState next) {
    if (!_disposed) value = next;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
