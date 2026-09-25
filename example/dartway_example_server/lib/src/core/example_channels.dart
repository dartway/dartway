import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The club's live channels, as handlers publish to them.
///
/// Who may hear each is declared with the feature that owns it
/// (`DwServerFeature(channels: …)`), and holds for any caller, not only for
/// the screen that subscribes — everything published to a channel is readable
/// by everyone its rule allows.
abstract final class ExampleChannels {
  /// The bookings channel of [accountId]'s member: where their "my bookings"
  /// hears a booking of theirs, whoever changed it.
  static DwLiveChannel bookingsOf(int accountId) =>
      DwLiveChannel.forAccount(ExampleChannel.bookings, accountId);

  /// The profile channel of [accountId]'s member: where their own profile
  /// hears a change to it, whoever made it.
  static DwLiveChannel profileOf(int accountId) =>
      DwLiveChannel.forAccount(ExampleChannel.profile, accountId);

  /// The staff chat channel [channelId]'s messages are published to.
  static DwLiveChannel chatOf(int channelId) =>
      DwLiveChannel(ExampleChannel.staffChat, channelId);
}
