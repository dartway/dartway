import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The app's live channels. The server declares who may subscribe to each; a
/// request declares which of them it lives on.
enum DartwayStarterChannel with DwChannelKind {
  /// One member's own profile: a caller channel (`DwLiveChannel.ofCaller`),
  /// keyed by the member's account. Its owner only. The router's admin guard
  /// follows it, so a role an admin changes moves the member at once.
  profile,

  /// App settings: every signed-in member.
  settings,

  /// What the admin panel shows — the counters, the members table, a user
  /// card. Admins only; a role taken away revokes it.
  admin,
}
