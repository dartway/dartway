import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';

/// What a notification says: the same for every recipient of one send.
final class DwPushMessage {
  const DwPushMessage({
    required this.title,
    this.body,
    this.data,
    this.link,
    this.imageUrl,
  });

  /// Shown as the notification's title. Required: a notification without
  /// one is drawn as the app's name, which says nothing.
  final String title;
  final String? body;

  /// The typed payload the app receives when the notification is opened: a
  /// data object of the protocol (see `DwPushData`).
  final DwDataObject? data;

  /// The in-app path a tap opens: `/news/12`. On the web it is also where
  /// the browser goes when the app is closed.
  final String? link;

  /// An image shown in the notification where the platform supports one.
  ///
  /// Providers show only an `https` image. One that is `http` — a development
  /// storage's public URL, typically — is accepted, and the notification goes
  /// without it: the picture is decoration, and the command that queued the
  /// message must not fail over it. `DwPushService.send` logs a warning
  /// naming the URL.
  final String? imageUrl;

  /// Whether a provider can show [imageUrl].
  bool get imageIsShowable => showsImage(imageUrl);

  /// Whether a provider can show an image at [url]: an `https` one.
  static bool showsImage(String? url) =>
      url != null && Uri.tryParse(url)?.scheme == 'https';

  static const int maxTitleLength = 200;
  static const int maxBodyLength = 2000;

  /// FCM refuses a message above 4 KiB; the data map is most of it.
  static const int maxDataBytes = 3000;

  /// The provider data map this message carries.
  Map<String, String> get wireData =>
      DwPushData(payload: data, link: link).toWire();

  /// Why this message cannot be sent, or `null`.
  String? problemIn(DwWireProtocol protocol) {
    if (title.trim().isEmpty) return 'the title is empty';
    if (title.length > maxTitleLength) {
      return 'the title is longer than $maxTitleLength characters';
    }
    if ((body?.length ?? 0) > maxBodyLength) {
      return 'the body is longer than $maxBodyLength characters';
    }
    if (data case final data? when !protocol.knows(data.runtimeType)) {
      return 'the data ${data.runtimeType} is not registered in the protocol';
    }
    if (link case final link? when !link.startsWith('/')) {
      return 'the link "$link" is not an in-app path starting with "/"';
    }
    if (imageUrl case final url?
        when !const {'http', 'https'}.contains(Uri.tryParse(url)?.scheme)) {
      return 'the image URL "$url" is not an http or https URL';
    }
    final size = wireData.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.key.length + entry.value.length,
    );
    if (size > maxDataBytes) {
      return 'the data and link take $size characters; at most '
          '$maxDataBytes fit a provider message';
    }
    return null;
  }
}

/// A message as the eligibility rule sees it, when its deliveries are due.
final class DwPushNotice {
  const DwPushNotice({
    required this.messageId,
    required this.category,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
  });

  final int messageId;

  /// The category's name (`DwPushCategory.categoryName`).
  final String category;
  final String title;
  final String? body;

  /// The payload and link, decoded by the server's protocol.
  final DwPushData data;
  final DateTime createdAt;

  /// Whether this message is of [category].
  bool isOf(DwPushCategory category) => this.category == category.categoryName;

  /// The value of [values] this message's category names, or `null`.
  T? categoryIn<T extends DwPushCategory>(List<T> values) {
    for (final value in values) {
      if (value.categoryName == category) return value;
    }
    return null;
  }
}

/// What the eligibility rule decides for one recipient of a due delivery.
sealed class DwPushDecision {
  const DwPushDecision._();

  /// Send now.
  static const DwPushDecision send = DwPushSendNow._();

  /// Do not send; the delivery is recorded as skipped (its dedup key stays
  /// used).
  static const DwPushDecision skip = DwPushSkip._();

  /// Ask again at [time] — quiet hours ending. The rule runs again then, so a
  /// recipient who opted out meanwhile is skipped. A time past the message's
  /// lifetime ends as expired.
  static DwPushDecision delayUntil(DateTime time) => DwPushDelay._(time);
}

final class DwPushSendNow extends DwPushDecision {
  const DwPushSendNow._() : super._();

  @override
  String toString() => 'DwPushDecision.send';
}

final class DwPushSkip extends DwPushDecision {
  const DwPushSkip._() : super._();

  @override
  String toString() => 'DwPushDecision.skip';
}

final class DwPushDelay extends DwPushDecision {
  const DwPushDelay._(this.time) : super._();

  final DateTime time;

  @override
  String toString() => 'DwPushDecision.delayUntil($time)';
}

/// Decides, when deliveries of [notice] fall due, what happens to each of
/// [accountIds] — in one call per message per batch, so a rule reads its
/// preferences with one query rather than one per recipient:
///
/// ```dart
/// eligibility: (ctx, notice, accountIds) async {
///   final optedIn = await ctx.db.userProfiles.find(
///     where: (t) => t.accountId.inList(accountIds) & t.agreedForMarketing.equals(true),
///   );
///   final allowed = {for (final p in optedIn) p.accountId};
///   return {
///     for (final id in accountIds)
///       if (!allowed.contains(id)) id: DwPushDecision.skip,
///   };
/// }
/// ```
///
/// **An account absent from the answer is sent to**; an answer for an
/// account that was not asked about fails the run. The rule runs inside the
/// claiming transaction: it reads, and does not call anything slow.
typedef DwPushEligibility =
    Future<Map<int, DwPushDecision>> Function(
      DwCallContext ctx,
      DwPushNotice notice,
      List<int> accountIds,
    );
