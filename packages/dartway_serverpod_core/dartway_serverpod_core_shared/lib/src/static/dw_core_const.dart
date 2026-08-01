class DwCoreConst {
  static const dartwayInternalApi = 'dartwayInternal';
  static const defaultApi = 'defaultApi';

  static const userProfileIdColumnName = 'id';
  static const userIdentifierColumnName = 'userIdentifier';

  /// A ready-made channel name for "everyone using this app", offered so both
  /// halves can agree on one spelling without a shared package to put it in.
  ///
  /// The core never posts here on its own: a config says where its updates go
  /// (`DwSaveConfig.broadcastTo`), and this is simply a name it may return.
  /// An app is free to ignore it and name its own channels.
  ///
  /// **The audience is literally everyone subscribed**, `accessFilter` and all.
  /// Use it for facts that are public to the whole audience anyway — a price,
  /// what is left in stock, a published post. Anything narrower deserves a
  /// narrower channel.
  static const publicUpdatesChannel = 'dwPublicUpdates';

  /// The prefix of the per-user channel behind [userUpdatesChannel].
  ///
  /// Declared once so the name and the `DwChannelConfig.owner` that guards it
  /// cannot drift apart.
  static const userUpdatesChannelPrefix = 'userUpdates';

  /// The channel one user's own updates travel on — what `sendUpdatesToUser`
  /// posts to, and what the app subscribes to for the signed-in user.
  ///
  /// Both halves build the name from here rather than from two string literals
  /// that agree today. The server refuses it for anyone but the user it names.
  static String userUpdatesChannel(int userProfileId) =>
      '$userUpdatesChannelPrefix$userProfileId';
}
