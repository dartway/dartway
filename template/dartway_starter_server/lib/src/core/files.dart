import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// File storage: the upload rules, and the default names of its buckets.
abstract final class AppFiles {
  /// The app's uploaded files: one rule per [DartwayStarterUpload].
  ///
  /// A rule's visibility is the whole decision about where a file goes: a public
  /// rule's files land in the public bucket and are read by URL; a private
  /// rule's would land in the private bucket and be read only through
  /// `DwGetFileLink` after a read check. Adding a purpose is adding its rule
  /// here — the buckets, the keys and the startup check follow from it.
  static List<DwUploadRule> get uploadRules => [
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

  /// The storage of [uploadRules] on [config].
  static DwFileStorage storage(DwFileStorageConfig config) =>
      DwFileStorage(config, rules: uploadRules);

  /// The default bucket names: `dartway create` names them after the project,
  /// as `dartway deploy` names the buckets of its bundled storage. Read by
  /// `AppEnvironment` when `DW_STORAGE_PUBLIC_BUCKET` / `_PRIVATE_BUCKET` are
  /// not set.
  static const defaultPublicBucket = 'dartway-starter-public';
  static const defaultPrivateBucket = 'dartway-starter-private';
}
