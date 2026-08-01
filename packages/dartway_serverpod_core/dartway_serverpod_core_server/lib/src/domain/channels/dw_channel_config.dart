import 'package:serverpod/serverpod.dart';

/// States who may listen to a realtime channel.
///
/// A channel is an audience, and until this existed the server had no way to
/// know who was in it: `subscribeOnUpdates` took a channel name as a plain
/// string from the client and opened it. Channel names are guessable by
/// construction — `userUpdates42`, `chatPost_message_course12` — so any caller
/// who could guess a name received someone else's updates. Authentication was
/// not the missing check: every one of those names is just as guessable by a
/// signed-in stranger.
///
/// Channels are declared in `DwCore.init(channelConfigurations: ...)`, and a
/// channel nobody declared is refused — the same law the CRUD configs follow.
///
/// A declaration matches by **prefix**, and the longest matching declaration
/// wins. Everything after the prefix is handed to the check as `suffix`, which
/// is where a channel carries its scope:
///
/// ```dart
/// DwChannelConfig.owner(prefix: 'userUpdates')        // userUpdates42  -> '42'
/// DwChannelConfig.guarded(prefix: 'chatPost_', ...)   // chatPost_c12   -> 'c12'
/// ```
///
/// **A prefix is a prefix.** `DwChannelConfig.public(prefix: 'updates')` also
/// opens `updates_admin_secrets`. Name a public channel in full, and give a
/// parametrised one a separator you would not write by accident (`chatPost_`,
/// not `chatPost`).
class DwChannelConfig {
  const DwChannelConfig._({
    required this.prefix,
    required this.allowAnonymous,
    required this.allowListen,
  });

  /// Open to everyone, signed in or not.
  ///
  /// For facts that are public to the whole audience anyway — a price, what is
  /// left in stock, a published post. One word, and it shows up in review;
  /// a permissive predicate never did.
  const DwChannelConfig.public({required String prefix})
    : this._(prefix: prefix, allowAnonymous: true, allowListen: null);

  /// Open to the one user whose profile id the channel name ends with.
  ///
  /// The shape behind `userUpdates42`, and the reason it is a constructor
  /// rather than a predicate every app rewrites: "my own updates" is the most
  /// common channel there is, and the version written by hand is the one that
  /// forgets to compare.
  const DwChannelConfig.owner({required String prefix})
    : this._(prefix: prefix, allowAnonymous: false, allowListen: null);

  /// Open to whoever [allowListen] says, given the session and the part of the
  /// channel name after [prefix].
  ///
  /// The suffix is the scope: for `chatPost_course12` it is `course12`, and the
  /// check is "is this caller in course 12". Parse it from the same helper that
  /// builds the name, so the two cannot drift.
  ///
  /// [allowAnonymous] defaults to `false`, and a caller with no session is
  /// turned away before [allowListen] runs — so the predicate never has to
  /// remember that it might be called without a user.
  const DwChannelConfig.guarded({
    required String prefix,
    required Future<bool> Function(Session session, String suffix) allowListen,
    bool allowAnonymous = false,
  }) : this._(
         prefix: prefix,
         allowAnonymous: allowAnonymous,
         allowListen: allowListen,
       );

  /// The start of every channel name this declaration governs.
  final String prefix;

  /// Whether a caller with no session may listen. See [DwChannelConfig.public].
  final bool allowAnonymous;

  /// The app's own check, or `null` for [public] (nothing to ask) and [owner]
  /// (the framework asks).
  final Future<bool> Function(Session session, String suffix)? allowListen;

  /// Whether this declaration governs [channel].
  bool matches(String channel) => channel.startsWith(prefix);

  /// Whether the caller may listen to [channel].
  ///
  /// Assumes [matches] — call it through `DwCore.canListenTo`, which picks the
  /// longest matching declaration first.
  ///
  /// [userProfileId] is passed in rather than read off [session] so that
  /// resolving the caller costs one lookup per subscription instead of one per
  /// candidate declaration — and so this decision can be tested without a
  /// database. [session] is here for [allowListen], which usually needs it.
  Future<bool> allows(
    Session session,
    String channel, {
    required int? userProfileId,
  }) async {
    if (userProfileId == null && !allowAnonymous) return false;

    final suffix = channel.substring(prefix.length);

    if (allowListen != null) return allowListen!(session, suffix);

    // No predicate: either public (anonymous already allowed above) or owner,
    // whose whole rule is that the suffix names the caller. A suffix that is
    // not a number is not this user's channel, so `tryParse` returning null
    // refuses rather than throws.
    if (allowAnonymous) return true;

    return int.tryParse(suffix) == userProfileId;
  }
}
