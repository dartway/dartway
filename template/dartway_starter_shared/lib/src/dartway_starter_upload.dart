import 'package:dartway_core_shared/dartway_core_shared.dart';

/// What an uploaded file is for. The server declares one rule per purpose —
/// who may upload, how large, which types, and public or private, which picks
/// the bucket.
enum DartwayStarterUpload with DwUploadPurpose {
  /// A member's profile photo. Public: kept in the public bucket and shown by
  /// its permanent URL to anyone who sees the profile.
  avatar;

  /// The largest avatar, in bytes. The server's rule and the app's picker read
  /// the same number, so a photo the server would refuse is not sent.
  static const int avatarMaxBytes = 5 * 1024 * 1024;

  /// The image types an avatar may have.
  static const Set<String> avatarContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };
}
