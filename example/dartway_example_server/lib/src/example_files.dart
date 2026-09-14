import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'chat/chat_files.dart';

/// The club's uploaded files: one rule per [ExampleUpload], and the storage
/// they are kept in.
///
/// A rule's visibility is the whole decision about where a file goes: a
/// public rule's files land in the public bucket and are read by URL, a
/// private rule's in the private bucket and are read only through
/// `DwGetFileLink` after [exampleCanRead]. Adding a purpose is adding its
/// rule here — the buckets, the keys and the startup check follow from it.
List<DwUploadRule> get exampleUploadRules => [
  DwUploadRule(
    ExampleUpload.avatar,
    visibility: DwFileVisibility.public,
    maxBytes: 5 * 1024 * 1024,
    contentTypes: {'image/jpeg', 'image/png', 'image/webp'},
    // Any member. The handler that puts a photo on a profile checks it is
    // the caller's own (`ctx.files.requireOwned`).
    canUpload: (ctx) async => true,
  ),
  chatAttachmentRule,
];

/// Who may read a private file through `DwGetFileLink`. The uploader, and
/// whoever a private purpose lets through — it answers for its own files
/// here (`file.isFor(ExampleUpload.…)`). Public files are never asked about.
Future<bool> exampleCanRead(DwCallContext ctx, DwFileRecord file) async =>
    await canReadChatAttachment(ctx, file) ?? file.accountId == ctx.accountId;

/// The storage of [exampleUploadRules] on [config].
DwFileStorage exampleFileStorage(DwFileStorageConfig config) =>
    DwFileStorage(config, rules: exampleUploadRules, canRead: exampleCanRead);

/// The example's storage configuration from [environment]: `DW_STORAGE_*` as
/// [DwFileStorageConfig.fromEnvironment] reads it, with the defaults of a
/// development MinIO filled in — buckets `club-public` and `club-private`,
/// the public one served from itself on the endpoint
/// (`<DW_STORAGE_ENDPOINT>/club-public`). `null` when `DW_STORAGE_ENDPOINT`
/// is not set: the server then runs without uploads.
///
/// A default that is wrong for a real storage does not pass silently: the
/// server checks at startup that the public bucket reads anonymously at its
/// base URL and the private one does not.
DwFileStorageConfig? exampleStorageConfig(Map<String, String> environment) {
  String? set(String key) => switch (environment[key]) {
    final value? when value.isNotEmpty => value,
    _ => null,
  };
  final endpoint = set('DW_STORAGE_ENDPOINT');
  if (endpoint == null) return null;
  final publicBucket = set('DW_STORAGE_PUBLIC_BUCKET') ?? 'club-public';
  final pathStyle = set('DW_STORAGE_PATH_STYLE')?.toLowerCase() != 'false';
  return DwFileStorageConfig.fromEnvironment({
    ...environment,
    'DW_STORAGE_PUBLIC_BUCKET': publicBucket,
    'DW_STORAGE_PRIVATE_BUCKET':
        set('DW_STORAGE_PRIVATE_BUCKET') ?? 'club-private',
    // Path-style only: a virtual-hosted base depends on DNS nobody set up for
    // a development storage.
    if (set('DW_STORAGE_PUBLIC_BASE_URL') == null && pathStyle)
      'DW_STORAGE_PUBLIC_BASE_URL':
          '${endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint}/$publicBucket',
  });
}
