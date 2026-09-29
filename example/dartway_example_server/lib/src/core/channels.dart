import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The club's live channels, as handlers publish to them.
///
/// Who may hear each is declared with the feature that owns it
/// (`DwServerFeature(channels: …)`), and holds for any caller, not only for
/// the screen that subscribes — everything published to a channel is readable
/// by everyone its rule allows.
abstract final class AppChannels {
  static const admin = DwLiveChannel(DartwayExampleChannel.admin);
  static const schedule = DwLiveChannel(DartwayExampleChannel.schedule);
  static const news = DwLiveChannel(DartwayExampleChannel.news);
  static const settings = DwLiveChannel(DartwayExampleChannel.settings);
  static const staffChannels = DwLiveChannel(
    DartwayExampleChannel.staffChannels,
  );

  /// The bookings channel of [accountId]'s member: where their "my bookings"
  /// hears a booking of theirs, whoever changed it.
  static DwLiveChannel bookingsOf(int accountId) =>
      DwLiveChannel.forAccount(DartwayExampleChannel.bookings, accountId);

  /// The profile channel of [accountId]'s member: where their own profile
  /// hears a change to it, whoever made it.
  static DwLiveChannel profileOf(int accountId) =>
      DwLiveChannel.forAccount(DartwayExampleChannel.profile, accountId);

  /// The staff chat channel [channelId]'s messages are published to.
  static DwLiveChannel chatOf(int channelId) =>
      DwLiveChannel(DartwayExampleChannel.staffChat, channelId);

  /// Where [accountId]'s staff member hears their read state of the chat.
  static DwLiveChannel chatReadsOf(int accountId) =>
      DwLiveChannel.forAccount(DartwayExampleChannel.chatReads, accountId);
}
