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
}
