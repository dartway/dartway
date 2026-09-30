/// The file storage's defaults.
///
/// Each upload purpose's rule is declared by the feature the purpose belongs
/// to, in its `_access.dart` — the avatar is the profile's, a chat attachment
/// the chat's — and the server's library hands them all to `DwFileStorage`,
/// with who may read a private file: `core/` imports no feature.
abstract final class AppFiles {
  /// The default bucket names, read by `AppEnvironment` when
  /// `DW_STORAGE_PUBLIC_BUCKET` / `_PRIVATE_BUCKET` are not set. A default
  /// that is wrong for a real storage does not pass silently: the server
  /// checks at startup that the public bucket reads anonymously at its base
  /// URL and the private one does not.
  static const defaultPublicBucket = 'club-public';
  static const defaultPrivateBucket = 'club-private';
}
