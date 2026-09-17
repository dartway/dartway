/// A kind of event. The project declares its events as an enum in its shared
/// package, so the app tracks them by name and nobody types a string:
///
/// ```dart
/// enum ShopEvent with DwAnalyticsEvent { catalogOpened, productViewed, orderPlaced }
/// ```
///
/// The server stores the name and needs no deploy for a new one: an event is
/// a fact about the app, not a call the server answers.
mixin DwAnalyticsEvent on Enum {
  /// The name stored with the event: the enum value's name, unless an enum
  /// overrides it. Letters, digits, `_` and `.`; `dw.` is the framework's.
  String get eventName => name;
}

/// The events the framework records by itself.
enum DwAppEvent with DwAnalyticsEvent {
  /// The app started (a cold start). Its properties carry the attribution the
  /// app was opened with, when the project reads one (UTM, a store referrer).
  appOpened,

  /// The app came back to the foreground.
  appResumed,

  /// The app went to the background.
  appBackgrounded,

  /// The account this install is signed in as changed: a sign-in, a switch,
  /// a sign-out. What follows is attributed to the new account.
  accountChanged;

  static const String prefix = 'dw.';

  @override
  String get eventName => '$prefix$name';
}
