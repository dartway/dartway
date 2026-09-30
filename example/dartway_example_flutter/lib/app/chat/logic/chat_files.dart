import 'dart:typed_data';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The staff chat's files: an attachment uploaded straight to storage before
/// the message is sent, and the link to one already sent.
abstract final class ChatFiles {
  /// Uploads [bytes] as a chat attachment, reporting [onProgress]; `null`
  /// when the file did not reach storage — the composer drops it and says so.
  static Future<DwStoredFile?> upload(
    String name,
    String contentType,
    Uint8List bytes, {
    required void Function(int sent, int total) onProgress,
  }) async {
    final result = await dw.files
        .upload(
          DartwayExampleUpload.chatAttachment,
          DwUploadSource.bytes(bytes),
          fileName: name,
          contentType: contentType,
          onProgress: onProgress,
        )
        .catchError((Object _) => const DwCallFailed<DwStoredFile>('upload'));
    return switch (result) {
      DwCallOk(:final value) => value,
      _ => null,
    };
  }

  /// The link to [attachment]. Run inside `dw.action`, which shows a refusal.
  static Future<String> linkOf(ChatAttachment attachment) async =>
      (await dw.files.getLink(attachment.id)).valueOrThrow.url;
}
