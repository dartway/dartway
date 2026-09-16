import 'package:collection/collection.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_session.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/profile/profile_roles.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The menu a chat message opens on a long press or a secondary tap.
abstract final class ChatMessageMenu {
  /// What can be done with a message, on a long press or a right click: a
  /// reaction, and reply, edit (one's own, within the edit window), copy,
  /// pin or unpin, delete (one's own, or any as an admin).
  ///
  /// The actions offered mirror the server's rules; the server checks them
  /// again and refuses the rest.
  static Future<void> show(
    BuildContext context, {
    required ChatMessage message,
    required ChatSession session,
    required UserProfile me,
  }) {
    final l10n = context.l10n;
    final mine = message.reactions
        .firstWhereOrNull((reaction) => reaction.id == me.id)
        ?.reaction;
    final kinds = chatReactionSigns.keys.toList();
    return context.showAppBottomSheet<void>(
      child: Builder(
        builder: (sheet) {
          void close() => Navigator.of(sheet).pop();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChatReactionPicker(
                signs: chatReactionSigns.values.toList(),
                selected: mine == null ? null : kinds.indexOf(mine),
                onSelected: (index) {
                  close();
                  dw.command(
                    ReactToChatMessage(
                      messageId: message.id,
                      reaction: kinds[index] == mine ? null : kinds[index],
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(l10n.chatReply),
                onTap: () {
                  close();
                  session.startReply(message);
                },
              ),
              if (message.editableBy(me.id))
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.chatEdit),
                  onTap: () {
                    close();
                    session.startEdit(message);
                  },
                ),
              if (message.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(l10n.chatCopyText),
                  onTap: () async {
                    close();
                    await Clipboard.setData(ClipboardData(text: message.text));
                    dw.notify.info(l10n.chatCopied);
                  },
                ),
              ListTile(
                leading: Icon(
                  message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(message.isPinned ? l10n.chatUnpin : l10n.chatPin),
                onTap: () {
                  close();
                  dw.command(
                    PinChatMessage(
                      messageId: message.id,
                      pinned: !message.isPinned,
                    ),
                  );
                },
              ),
              if (message.author.id == me.id || me.isClubAdmin)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.chatDelete),
                  onTap: () async {
                    close();
                    final sure = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: Text(l10n.chatDeleteQuestion),
                        content: Text(l10n.chatDeleteExplanation),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialog).pop(false),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialog).pop(true),
                            child: Text(l10n.chatDelete),
                          ),
                        ],
                      ),
                    );
                    if (sure == true) {
                      await dw.command(
                        DeleteChatMessage(messageId: message.id),
                      );
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
