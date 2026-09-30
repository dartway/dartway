/// The file storage's defaults.
///
/// Each upload purpose's rule is declared by the feature the purpose belongs
/// to, in its `_access.dart` (the avatar is the profile's), and the server's
/// library hands them all to `DwFileStorage` — `core/` imports no feature.
/// A rule's visibility is the whole decision about where a file goes: a
/// public rule's files land in the public bucket and are read by URL; a
/// private rule's in the private bucket, read only through `DwGetFileLink`
/// after a read check.
abstract final class AppFiles {
  /// The default bucket names: `dartway create` names them after the project,
  /// as `dartway deploy` names the buckets of its bundled storage. Read by
  /// `AppEnvironment` when `DW_STORAGE_PUBLIC_BUCKET` / `_PRIVATE_BUCKET` are
  /// not set.
  static const defaultPublicBucket = 'dartway-starter-public';
  static const defaultPrivateBucket = 'dartway-starter-private';
}
