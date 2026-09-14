import 'dart:async';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/foundation.dart';

/// One open channel of the staff chat: what its parts share — the list's
/// controller, the message being replied to or edited, the search.
///
/// Lives as long as the channel is on screen; the screen disposes it.
final class ChatSession {
  ChatSession({required this.channel, required ChatReadState? readState})
    : request = ListChatMessages(channelId: channel.id),
      // Opened at the read position only when something after it is unread:
      // a read chat opens at its newest message.
      openAnchor = (readState?.unreadCount ?? 0) > 0
          ? readState?.lastReadCursor
          : null,
      readAtOpen = (readState?.unreadCount ?? 0) > 0
          ? readState?.lastReadCursor
          : null;

  final ChatChannel channel;
  final ListChatMessages request;

  /// Where the list opens; `null` at the newest message.
  final String? openAnchor;

  /// The read position as the chat was opened, while something was unread:
  /// where the unread divider stands for as long as the chat is open.
  final String? readAtOpen;

  late final DwWindowPosition<Object, Object>? readPositionAtOpen =
      switch (readAtOpen) {
        final cursor? => DwWindowCursor.decode(cursor).position,
        null => null,
      };

  final list = DwWindowListController<ChatMessage>();

  /// The message the composer answers; `null` when not replying.
  final replyTo = ValueNotifier<ChatMessage?>(null);

  /// The message the composer edits; `null` when writing a new one.
  final editing = ValueNotifier<ChatMessage?>(null);

  /// Opens the window around [quote] and highlights it — a reply's quote, a
  /// pinned message, a search result.
  Future<bool> showMessage(int id, DateTime sentAt) =>
      list.scrollToCursor(DwWindowCursor.encode(sentAt, id));

  void startReply(ChatMessage message) {
    editing.value = null;
    replyTo.value = message;
  }

  void startEdit(ChatMessage message) {
    replyTo.value = null;
    editing.value = message;
  }

  void dispose() {
    list.dispose();
    replyTo.dispose();
    editing.dispose();
  }
}

/// Moves the caller's read position forward as messages come on screen:
/// only forward, at most once per [debounce], and once more as the chat
/// closes.
final class ChatReadTracker {
  ChatReadTracker({
    required this.channelId,
    required this.request,
    DwWindowPosition<Object, Object>? readPosition,
    this.debounce = const Duration(milliseconds: 1200),
  }) : _marked = readPosition;

  final int channelId;
  final ListChatMessages request;
  final Duration debounce;

  DwWindowPosition<Object, Object>? _marked;
  ChatMessage? _pending;
  Timer? _timer;

  /// [visible] is newest first, as the list reports it.
  void seen(List<ChatMessage> visible) {
    final newest = visible.firstOrNull;
    if (newest == null) return;
    final position = request.positionOf(newest);
    final pending = _pending;
    final ahead = pending == null ? _marked : request.positionOf(pending);
    if (ahead != null &&
        DwWindowCursor.comparePositions(position, ahead) <= 0) {
      return;
    }
    _pending = newest;
    _timer ??= Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    _marked = request.positionOf(pending);
    // Best effort: a lost mark is taken again by the next one, and the
    // server never moves a position back.
    unawaited(
      dw.command(MarkChatRead(channelId: channelId, messageId: pending.id)),
    );
  }

  void dispose() => flush();
}
