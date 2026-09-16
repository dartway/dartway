import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The files of a message: pictures laid out at their size before they load,
/// documents as tiles. Private files: every one is read through a
/// short-lived link the server gives staff only.
class ChatAttachmentsView extends StatelessWidget {
  const ChatAttachmentsView({required this.attachments, super.key});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images = [
      for (final attachment in attachments)
        if (attachment.isImage) attachment,
    ];
    final files = [
      for (final attachment in attachments)
        if (!attachment.isImage) attachment,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final image in images)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ChatImageFrame(
              aspectRatio: switch ((image.width, image.height)) {
                (final w?, final h?) when w > 0 && h > 0 => (w / h).clamp(
                  0.5,
                  2.5,
                ),
                _ => 4 / 3,
              },
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(child: ChatLinkedImage(image.id)),
                ),
              ),
              child: ChatLinkedImage(image.id),
            ),
          ),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _FileLinkTile(file: file),
          ),
      ],
    );
  }
}

/// A private picture by its file id: the link is asked for when the picture
/// is about to be shown, and again once it has expired.
class ChatLinkedImage extends HookConsumerWidget {
  const ChatLinkedImage(this.fileId, {super.key});

  final int fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dw.request(DwGetFileLink(fileId: fileId));
    final link = ref.watch(provider);
    final retried = useRef(false);
    return switch (link) {
      AsyncData(:final value) => Image.network(
        value.url,
        key: ValueKey(value.url),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          // An expired link: ask for a new one, once.
          if (!retried.value) {
            retried.value = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => ref.read(provider.notifier).refetch(),
            );
          }
          return const Center(child: Icon(Icons.broken_image_outlined));
        },
      ),
      AsyncError() => const Center(child: Icon(Icons.lock_outline)),
      _ => const SizedBox.expand(),
    };
  }
}

class _FileLinkTile extends ConsumerWidget {
  const _FileLinkTile({required this.file});

  final ChatAttachment file;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChatFileTile(
    name: file.fileName,
    sizeLabel: file.byteSize.fileSizeLabel,
    onTap: () async {
      // No browser or viewer plugin in the example: the link is handed over.
      final link = await dw.files.getLink(file.id);
      if (link case DwCallOk(:final value)) {
        await Clipboard.setData(ClipboardData(text: value.url));
        if (context.mounted) dw.notify.info(context.l10n.chatCopied);
      }
    },
  );
}
