import 'package:collection/collection.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_session.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_attachments_view.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_menu.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';

/// One message of the list with what stands above it: the day it starts, the
/// unread divider, the author's name and avatar for the first and last of a
/// run.
class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({
    required this.row,
    required this.session,
    this.searchQuery,
    super.key,
  });

  final DwWindowListItem<ChatMessage> row;
  final ChatSession session;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = row.item;
    final me = context.profile;
    final isMine = message.author.id == me.id;
    final older = row.older;
    final newer = row.newer;
    final startsDay =
        older == null || !message.sentAt.isSameLocalDay(older.sentAt);
    final read = session.readPositionAtOpen;
    final request = session.request;
    final firstUnread =
        read != null &&
        older != null &&
        DwWindowCursor.comparePositions(request.positionOf(message), read) >
            0 &&
        DwWindowCursor.comparePositions(request.positionOf(older), read) <= 0;
    final first = startsDay || firstUnread || !message.continues(older);
    final last = newer == null || !newer.continues(message);

    final bubble = ChatBubbleContainer(
      isMine: isMine,
      isFirstInGroup: first,
      isLastInGroup: last,
      isHighlighted: row.isHighlighted,
      maxWidth: MediaQuery.sizeOf(context).width * 0.78 > 420
          ? 420
          : MediaQuery.sizeOf(context).width * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine && first) ChatAuthorName(message.authorName),
          if (message.replyTo case final quote?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ChatQuoteBlock(
                title: quote.authorName,
                text: quote.isDeleted
                    ? l10n.chatDeletedMessage
                    : quote.text.isEmpty && quote.hasAttachments
                    ? l10n.chatPhoto
                    : quote.text,
                muted: quote.isDeleted,
                onTap: quote.isDeleted
                    ? null
                    : () async {
                        final found = await session.showMessage(
                          quote.id,
                          quote.sentAt,
                        );
                        if (!found) dw.notify.warning(l10n.chatMessageGone);
                      },
              ),
            ),
          if (message.attachments.isNotEmpty)
            ChatAttachmentsView(attachments: message.attachments),
          if (message.text.isNotEmpty)
            ChatHighlightedText(message.text, query: searchQuery),
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              ..._reactions(message, me.id),
              ChatMessageMeta(
                time: message.sentAt.timeLabel,
                editedLabel: message.editedAt == null ? null : l10n.chatEdited,
                isPinned: message.isPinned,
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (startsDay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ChatDateChip(message.sentAt.chatDayLabel(l10n)),
          ),
        if (firstUnread) ChatUnreadDivider(l10n.chatUnreadDivider),
        Padding(
          padding: EdgeInsets.only(top: first ? 6 : 2),
          child: Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                ChatAuthorAvatar(name: message.authorName, visible: last),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => showChatMessageMenu(
                    context,
                    message: message,
                    session: session,
                    me: me,
                  ),
                  onSecondaryTap: () => showChatMessageMenu(
                    context,
                    message: message,
                    session: session,
                    me: me,
                  ),
                  child: bubble,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _reactions(ChatMessage message, int myId) {
    if (message.reactions.isEmpty) return const [];
    final mine = message.reactions
        .firstWhereOrNull((reaction) => reaction.id == myId)
        ?.reaction;
    final counts = <ChatReaction, int>{};
    for (final reaction in message.reactions) {
      counts[reaction.reaction] = (counts[reaction.reaction] ?? 0) + 1;
    }
    return [
      for (final kind in ChatReaction.values)
        if (counts[kind] case final count?)
          ChatReactionPill(
            key: ValueKey('reaction-${message.id}-${kind.name}'),
            sign: chatReactionSigns[kind]!,
            count: count,
            isMine: mine == kind,
            onTap: () => dw.command(
              ReactToChatMessage(
                messageId: message.id,
                reaction: mine == kind ? null : kind,
              ),
            ),
          ),
    ];
  }
}
