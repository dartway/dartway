/// Data keys the server half writes when a transport cannot carry a
/// notification of its own — RuStore with an image, which arrives as data and
/// is drawn by the device.
///
/// The wire contract between the two halves of the module. The same literals
/// live in `dartway_push_server`, and both sides pin them with a test against
/// the strings rather than against each other's constant: a device reading a
/// key the server stopped writing shows nothing at all, and shows it silently.
const dwPushTitleDataKey = 'push_title';
const dwPushBodyDataKey = 'push_body';
const dwPushImageUrlDataKey = 'image_url';

/// Where a ready-made in-app path is carried, for the one client that cannot
/// build its own: a web service worker handles the click outside Flutter, with
/// no router in reach.
const dwPushLinkDataKey = 'link';

/// How a notification reached the app.
enum DwPushOpenSource {
  /// The app was not running and the notification started it.
  coldStart,

  /// The app was in the background and came forward.
  background,

  /// The app was on screen when the user tapped the notification.
  foreground,

  /// A web service worker handled the click and handed over a path.
  webLink,
}

/// A notification the user opened.
///
/// Deliberately a data map rather than a typed payload: which keys mean what is
/// the app's business, and a framework type here would either be empty or be
/// somebody else's domain. Parse it into your own model at the edge.
final class DwPushOpened {
  const DwPushOpened({required this.data, required this.source, this.link});

  final Map<String, String> data;
  final DwPushOpenSource source;

  /// The path the server built for the web click handler, when there is one.
  final String? link;

  @override
  String toString() =>
      'DwPushOpened(source: ${source.name}, keys: ${data.keys.toList()})';
}

/// A notification that arrived while the app was on screen.
///
/// Reported, never acted on: the platform decides whether it is also shown, and
/// pulling the user off their current screen because something arrived is a
/// choice only the app gets to make.
final class DwPushReceived {
  const DwPushReceived({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, String> data;

  /// The title as sent, whether it came in the notification or, for a
  /// data-only message, in [dwPushTitleDataKey].
  String? get effectiveTitle => title ?? data[dwPushTitleDataKey];

  String? get effectiveBody => body ?? data[dwPushBodyDataKey];

  String? get imageUrl => data[dwPushImageUrlDataKey];
}
