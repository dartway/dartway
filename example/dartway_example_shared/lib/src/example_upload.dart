import 'package:dartway_core_shared/dartway_core_shared.dart';

/// What the example's uploaded files are for. The server declares one rule
/// per purpose: who may upload, how large, which types, public or private.
enum ExampleUpload with DwUploadPurpose {
  /// A member's profile photo. Public: kept in the public bucket and shown by
  /// its permanent URL to anyone who sees the profile.
  avatar,

  /// A picture or a document attached to a staff chat message. Private: read
  /// through short-lived links that only staff get, and only while the
  /// message it is attached to exists.
  chatAttachment,
}
