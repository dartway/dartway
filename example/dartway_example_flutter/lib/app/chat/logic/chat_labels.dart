import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:intl/intl.dart';

/// The sign each reaction is shown as, in the order the picker offers them.
const Map<ChatReaction, String> chatReactionSigns = {
  ChatReaction.heart: '❤️',
  ChatReaction.fire: '🔥',
  ChatReaction.thumbsUp: '👍',
  ChatReaction.thumbsDown: '👎',
  ChatReaction.money: '💰',
};

/// How long apart two messages of one author may be and still read as one
/// run of bubbles.
const Duration chatGroupGap = Duration(minutes: 10);

extension ChatDayLabel on DateTime {
  /// "Today", "Yesterday", a weekday-less date this year, a full one before.
  String chatDayLabel(AppLocalizations l10n, {DateTime? now}) {
    final local = toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = todayDay.difference(day).inDays;
    if (days == 0) return l10n.chatToday;
    if (days == 1) return l10n.chatYesterday;
    return local.year == today.year
        ? DateFormat.MMMMd().format(local)
        : DateFormat.yMMMMd().format(local);
  }

  bool isSameLocalDay(DateTime other) {
    final a = toLocal();
    final b = other.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// "12 KB", "3.4 MB".
String chatFileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

extension ChatMessageFacts on ChatMessage {
  /// Whether [older] and this message are one author's run.
  bool continues(ChatMessage? older) =>
      older != null &&
      older.author.id == author.id &&
      sentAt.isSameLocalDay(older.sentAt) &&
      sentAt.difference(older.sentAt) <= chatGroupGap;

  String get authorName => [
    author.firstName,
    if (author.lastName case final last? when last.isNotEmpty) last,
  ].join(' ');

  /// Whether [profileId]'s author may still edit it at [now].
  bool editableBy(int profileId, {DateTime? now}) =>
      author.id == profileId &&
      (now ?? DateTime.now()).difference(sentAt) < ChatMessage.editWindow;
}
