import 'package:dartway_core/dartway_core.dart';

/// The example's realtime channels. The server declares who may subscribe to
/// each; a request declares which of them it lives on.
enum ExampleChannel with DwChannelKind {
  /// The club schedule and service catalogue: public to signed-in users.
  schedule,

  /// One client's bookings. Key: the client's profile id.
  bookings,

  /// News posts: public to signed-in users.
  news,

  /// Messages of one staff chat channel. Key: the chat channel id. Staff only.
  staffChat,

  /// The list of staff chat channels. Staff only.
  staffChannels,

  /// App settings: public to signed-in users.
  settings,

  /// The signed-in user's own profile. Key: the account id. Its owner only.
  profile,

  /// Everything the admin dashboard and users table show. Admin only.
  admin,
}
