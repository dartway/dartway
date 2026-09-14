part of '../../ui_kit.dart';

/// A picture in a bubble, sized by its known dimensions before it loads, so
/// nothing in the list moves when it arrives.
class ChatImageFrame extends StatelessWidget {
  const ChatImageFrame({
    required this.aspectRatio,
    required this.child,
    this.onTap,
    super.key,
  });

  final double aspectRatio;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        color: context.colorScheme.surfaceContainerHigh,
        child: InkWell(onTap: onTap, child: child),
      ),
    ),
  );
}

/// A document in a bubble or in the composer: its name and size.
class ChatFileTile extends StatelessWidget {
  const ChatFileTile({
    required this.name,
    required this.sizeLabel,
    this.onTap,
    this.onRemove,
    this.progress,
    this.removeTooltip,
    this.thumbnail,
    super.key,
  });

  final String name;
  final String sizeLabel;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  /// While uploading: 0..1.
  final double? progress;
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 36,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      thumbnail ??
                      ColoredBox(
                        color: colors.primaryContainer,
                        child: Icon(
                          Icons.insert_drive_file_outlined,
                          size: 20,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.body
                          .resolve(context)
                          .copyWith(fontSize: 13),
                    ),
                    if (progress != null)
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(value: progress),
                      )
                    else
                      Text(
                        sizeLabel,
                        style: AppTextStyle.caption.resolve(context),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: removeTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text with every occurrence of [query] marked — the matches of a search.
class ChatHighlightedText extends StatelessWidget {
  const ChatHighlightedText(this.text, {this.query, super.key});

  final String text;
  final String? query;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.body.resolve(context);
    final needle = query?.trim().toLowerCase() ?? '';
    if (needle.isEmpty) return Text(text, style: style);
    final haystack = text.toLowerCase();
    final spans = <TextSpan>[];
    var at = 0;
    while (true) {
      final found = haystack.indexOf(needle, at);
      if (found < 0) break;
      if (found > at) spans.add(TextSpan(text: text.substring(at, found)));
      spans.add(
        TextSpan(
          text: text.substring(found, found + needle.length),
          style: TextStyle(
            backgroundColor: context.colorScheme.tertiaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      at = found + needle.length;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
