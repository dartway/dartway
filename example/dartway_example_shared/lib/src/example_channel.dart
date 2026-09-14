import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The example's live channels. The server declares who may subscribe to
/// each; a request declares which of them it lives on.
enum ExampleChannel with DwChannelKind {
  /// The club schedule and service catalogue: every signed-in member.
  schedule,

  /// One member's bookings: a caller channel (`DwLiveChannel.ofCaller`),
  /// keyed by the member's account. Its owner only.
  bookings,

  /// News posts: every signed-in member.
  news,

  /// Messages of one staff chat channel. Key: the chat channel id. Staff only.
  staffChat,

  /// The list of staff chat channels. Staff only.
  staffChannels,

  /// One staff member's read state of the chat channels: a caller channel,
  /// keyed by the member's account. Its owner only.
  chatReads,

  /// App settings: every signed-in member.
  settings,

  /// One member's own profile: a caller channel, keyed by the member's
  /// account. Its owner only.
  profile,

  /// What the admin dashboard and the members table show. Admins only.
  admin,
}
