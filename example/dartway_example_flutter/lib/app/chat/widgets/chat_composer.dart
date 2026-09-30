import 'dart:async';
import 'dart:ui' as ui;

import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_commands.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_composing_controller.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_files.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_session.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// What each staff chat channel's composer held when it was left, for this
/// app session.
final chatDraftsProvider = Provider<Map<int, String>>((ref) => {});

/// The largest attachment the server's rule takes.
const int chatAttachmentMaxBytes = 20 * 1024 * 1024;

const Map<String, String> _contentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
};

/// A file on its way into a message.
@immutable
final class ChatComposerFile {
  const ChatComposerFile({
    required this.key,
    required this.name,
    required this.byteSize,
    this.bytes,
    this.progress = 0,
    this.stored,
    this.width,
    this.height,
  });

  final int key;
  final String name;
  final int byteSize;
  final Uint8List? bytes;
  final double progress;
  final DwStoredFile? stored;
  final int? width;
  final int? height;

  bool get isUploading => stored == null;

  ChatComposerFile copyWith({double? progress, DwStoredFile? stored}) =>
      ChatComposerFile(
        key: key,
        name: name,
        byteSize: byteSize,
        bytes: bytes,
        progress: progress ?? this.progress,
        stored: stored ?? this.stored,
        width: width,
        height: height,
      );
}

/// The composer: a field that grows to a few lines, Enter sends (Shift+Enter
/// breaks the line), files attached before sending upload at once, and a
/// banner over it while replying or editing.
///
/// The sent message is not added here: it arrives in the command's answer and
/// on the channel. After sending, the list goes to the newest message.
class ChatComposer extends HookConsumerWidget {
  const ChatComposer({required this.session, super.key});

  final ChatSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final channelId = session.channel.id;
    final drafts = ref.read(chatDraftsProvider);
    final controller = useTextEditingController(text: drafts[channelId] ?? '');
    final focus = useFocusNode();
    final composing = ref.read(chatComposingProvider(channelId).notifier);
    final ChatComposing(:replyTo, :editing) = ref.watch(
      chatComposingProvider(channelId),
    );
    // Read by the cleanup below, which runs after the last build.
    final editingNow = useRef(editing)..value = editing;
    final files = useState<List<ChatComposerFile>>(const []);
    final text = useValueListenable(controller).text;
    final sending = useState(false);
    final nextKey = useRef(0);

    // Editing takes the field over; leaving the edit gives the draft back.
    final draftBeforeEdit = useRef<String?>(null);
    useEffect(() {
      if (editing != null) {
        draftBeforeEdit.value ??= controller.text;
        controller.text = editing.text;
        focus.requestFocus();
      } else if (draftBeforeEdit.value case final draft?) {
        draftBeforeEdit.value = null;
        controller.text = draft;
      }
      return null;
    }, [editing?.id]);
    useEffect(() {
      if (replyTo != null) focus.requestFocus();
      return null;
    }, [replyTo?.id]);
    useEffect(
      () => () {
        if (editingNow.value == null) {
          drafts[channelId] = controller.text;
        }
      },
      const [],
    );

    final uploading = files.value.any((file) => file.isUploading);
    final canSend =
        !sending.value &&
        !uploading &&
        (text.trim().isNotEmpty ||
            (editing == null && files.value.isNotEmpty) ||
            (editing != null && editing.attachments.isNotEmpty));

    Future<void> send() async {
      if (!canSend) return;
      sending.value = true;
      try {
        // A refusal or a failure is shown by the action; the draft stays.
        final result = await dw.action(
          (_) => editing != null
              ? ChatCommands.edit(editing, controller.text)
              : ChatCommands.send(
                  channelId,
                  controller.text,
                  replyTo: replyTo,
                  attachments: [
                    for (final file in files.value)
                      ChatAttachmentDraft(
                        id: file.stored!.id,
                        width: file.width,
                        height: file.height,
                      ),
                  ],
                ),
          label: editing != null ? 'editChatMessage' : 'sendChatMessage',
          onErrorNotification: l10n.actionFailed,
        )(context);
        if (result == null || !context.mounted) return;
        if (editing != null) {
          draftBeforeEdit.value = null;
          composing.clear();
          controller.clear();
        } else {
          controller.clear();
          drafts.remove(channelId);
          files.value = const [];
          composing.clear();
          unawaited(session.list.jumpToNewest());
        }
      } finally {
        if (context.mounted) sending.value = false;
      }
    }

    focus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        unawaited(send());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    Future<void> attach() async {
      final room = ChatMessage.maxAttachments - files.value.length;
      if (room <= 0) {
        dw.notify.error(l10n.chatAttachmentLimit(ChatMessage.maxAttachments));
        return;
      }
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: _contentTypes.keys.toList(),
      );
      if (picked == null || !context.mounted) return;
      var chosen = picked.files;
      if (chosen.length > room) {
        dw.notify.error(l10n.chatAttachmentLimit(ChatMessage.maxAttachments));
        chosen = chosen.take(room).toList();
      }
      for (final platformFile in chosen) {
        final bytes = platformFile.bytes;
        final extension = (platformFile.extension ?? '').toLowerCase();
        final contentType = _contentTypes[extension];
        if (bytes == null || contentType == null) continue;
        if (bytes.length > chatAttachmentMaxBytes) {
          dw.notify.error(
            l10n.chatFileTooLarge(
              platformFile.name,
              chatAttachmentMaxBytes ~/ (1024 * 1024),
            ),
          );
          continue;
        }
        unawaited(
          _upload(
            files,
            nextKey.value++,
            platformFile.name,
            contentType,
            bytes,
            onFailed: () =>
                dw.notify.error(l10n.chatUploadFailed(platformFile.name)),
          ),
        );
      }
    }

    return ChatBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (editing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s6),
              child: ChatQuoteBlock(
                icon: Icons.edit_outlined,
                title: l10n.chatEditingMessage,
                text: editing.text,
                cancelTooltip: l10n.cancel,
                onCancel: composing.clear,
              ),
            )
          else if (replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s6),
              child: ChatQuoteBlock(
                icon: Icons.reply,
                title: l10n.chatReplyTo(replyTo.authorNameIn(l10n)),
                text: replyTo.text.isEmpty ? l10n.chatPhoto : replyTo.text,
                cancelTooltip: l10n.cancel,
                onTap: () => session.showMessage(replyTo.id, replyTo.sentAt),
                onCancel: composing.clear,
              ),
            ),
          if (files.value.isNotEmpty && editing == null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s6),
              child: Wrap(
                spacing: AppSpace.s6,
                runSpacing: AppSpace.s6,
                children: [
                  for (final file in files.value)
                    ChatFileTile(
                      key: ValueKey('composer-file-${file.key}'),
                      name: file.name,
                      sizeLabel: file.byteSize.fileSizeLabel,
                      progress: file.isUploading ? file.progress : null,
                      removeTooltip: l10n.cancel,
                      thumbnail: file.width != null && file.bytes != null
                          ? Image.memory(file.bytes!, fit: BoxFit.cover)
                          : null,
                      onRemove: () => files.value = [
                        for (final other in files.value)
                          if (other.key != file.key) other,
                      ],
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ChatMessageField(
                  controller: controller,
                  focusNode: focus,
                  hintText: l10n.messageTheTeam,
                  prefix: editing == null
                      ? IconButton(
                          key: const ValueKey('chat-attach'),
                          tooltip: l10n.chatAttachFile,
                          onPressed: attach,
                          icon: const Icon(Icons.attach_file),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpace.s6),
              IconButton.filled(
                key: const ValueKey('chat-send'),
                tooltip: l10n.sendMessage,
                onPressed: canSend ? send : null,
                icon: sending.value
                    ? const AppProgressIndicator(size: 18)
                    : Icon(editing == null ? Icons.send : Icons.check),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Uploads one picked file into [files], reporting progress as it goes.
  static Future<void> _upload(
    ValueNotifier<List<ChatComposerFile>> files,
    int key,
    String name,
    String contentType,
    Uint8List bytes, {
    required VoidCallback onFailed,
  }) async {
    int? width;
    int? height;
    if (contentType.startsWith('image/')) {
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        width = frame.image.width;
        height = frame.image.height;
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        // A picture that does not decode here is sent without its size.
      }
    }
    files.value = [
      ...files.value,
      ChatComposerFile(
        key: key,
        name: name,
        byteSize: bytes.length,
        bytes: bytes,
        width: width,
        height: height,
      ),
    ];
    void update(ChatComposerFile Function(ChatComposerFile) change) {
      files.value = [
        for (final file in files.value) file.key == key ? change(file) : file,
      ];
    }

    final stored = await ChatFiles.upload(
      name,
      contentType,
      bytes,
      onProgress: (sent, total) => update(
        (file) => file.copyWith(progress: total == 0 ? 1 : sent / total),
      ),
    );
    if (stored != null) {
      update((file) => file.copyWith(progress: 1, stored: stored));
    } else {
      files.value = [
        for (final file in files.value)
          if (file.key != key) file,
      ];
      onFailed();
    }
  }
}
