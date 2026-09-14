import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// The app's uploaded files: one rule per [DartwayStarterUpload].
///
/// A rule's visibility is the whole decision about where a file goes: a public
/// rule's files land in the public bucket and are read by URL; a private
/// rule's would land in the private bucket and be read only through
/// `DwGetFileLink` after a read check. Adding a purpose is adding its rule
/// here — the buckets, the keys and the startup check follow from it.
List<DwUploadRule> get appUploadRules => [
  DwUploadRule(
    DartwayStarterUpload.avatar,
    // Shown to anyone who sees the member, by URL: a photo is not private.
    visibility: DwFileVisibility.public,
    maxBytes: DartwayStarterUpload.avatarMaxBytes,
    contentTypes: DartwayStarterUpload.avatarContentTypes,
    // Any member. The command that puts a photo on a profile checks it is the
    // caller's own finished upload (`ctx.files.requireOwned`).
    canUpload: (ctx) async => true,
  ),
];

/// The storage of [appUploadRules] on [config].
DwFileStorage appFileStorage(DwFileStorageConfig config) =>
    DwFileStorage(config, rules: appUploadRules);

/// The default bucket names: `dartway create` names them after the project,
/// as `dartway deploy` names the buckets of its MinIO.
const defaultPublicBucket = 'dartway-starter-public';
const defaultPrivateBucket = 'dartway-starter-private';

/// The storage configuration from [environment]: `DW_STORAGE_*` as
/// [DwFileStorageConfig.fromEnvironment] reads it, with the defaults of a
/// development MinIO filled in — buckets [defaultPublicBucket] and
/// [defaultPrivateBucket], the public one served from itself on the endpoint
/// (`<DW_STORAGE_ENDPOINT>/<public bucket>`, path style). `null` when
/// `DW_STORAGE_ENDPOINT` is not set: the server then runs without uploads.
///
/// A default that is wrong for a real storage does not pass silently: the
/// server checks at startup that the public bucket reads anonymously at its
/// base URL and the private one does not (`DW_STORAGE_VERIFY_BUCKETS`).
DwFileStorageConfig? appStorageConfig(Map<String, String> environment) {
  String? set(String key) => switch (environment[key]) {
    final value? when value.isNotEmpty => value,
    _ => null,
  };
  final endpoint = set('DW_STORAGE_ENDPOINT');
  if (endpoint == null) return null;
  final publicBucket = set('DW_STORAGE_PUBLIC_BUCKET') ?? defaultPublicBucket;
  final pathStyle = set('DW_STORAGE_PATH_STYLE')?.toLowerCase() != 'false';
  final base = endpoint.endsWith('/')
      ? endpoint.substring(0, endpoint.length - 1)
      : endpoint;
  return DwFileStorageConfig.fromEnvironment({
    ...environment,
    'DW_STORAGE_PUBLIC_BUCKET': publicBucket,
    'DW_STORAGE_PRIVATE_BUCKET':
        set('DW_STORAGE_PRIVATE_BUCKET') ?? defaultPrivateBucket,
    // Path style only: a virtual-hosted base depends on DNS nobody set up for
    // a development storage.
    if (set('DW_STORAGE_PUBLIC_BASE_URL') == null && pathStyle)
      'DW_STORAGE_PUBLIC_BASE_URL': '$base/$publicBucket',
  });
}
