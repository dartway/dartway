import 'dw_alert_context.dart';

/// Builds ready-to-send Telegram MarkdownV2 alert messages: the template
/// markup (bold headers, the stack code block) survives, every inserted value
/// is escaped, the stack trace is trimmed and the total length is guaranteed
/// to fit the Telegram limit.
abstract final class DwAlertFormatter {
  static const telegramMessageLimit = 4096;
  static const defaultStackTraceMaxLines = 8;

  /// Longest error/exception text rendered before truncation — keeps a single
  /// huge error from starving the context and stack sections.
  static const _valueLimit = 1200;

  /// Escapes MarkdownV2 reserved characters in a VALUE (not in the template).
  static String escapeMarkdownV2(String value) => value.replaceAllMapped(
        RegExp(r'([_*\[\]()~`>#+\-=|{}.!\\])'),
        (m) => '\\${m.group(1)}',
      );

  /// Inside a MarkdownV2 code block only backticks and backslashes need care.
  static String _escapeCodeBlock(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll('`', '\\`');

  static String _clip(String value) => value.length <= _valueLimit
      ? value
      : '${value.substring(0, _valueLimit)}…';

  /// Renders the full alert. Sections without a value are omitted:
  ///
  /// ```
  /// ❌ *Error*
  /// Action failed: deleteFaqQuestion
  ///
  /// 📌 *Exception*
  /// PostgreSQLException: ...
  ///
  /// 🖥 web/android · v1.4.2 · user 42
  /// 📍 /admin/help
  /// 🧩 faq-admin, admin-shell
  /// ⚡ Action: deleteFaqQuestion
  /// 🏷 tenant: acme
  ///
  /// 📜 *StackTrace* (top 8)
  /// ```<stack lines>```
  /// ```
  static String formatErrorReport({
    required String errorMessage,
    Object? exception,
    StackTrace? stackTrace,
    DwAlertContext? context,
    int? stackTraceMaxLines = defaultStackTraceMaxLines,
  }) {
    final sections = <String>[
      '❌ *Error*\n${escapeMarkdownV2(_clip(errorMessage))}',
      if (exception != null)
        '📌 *Exception*\n${escapeMarkdownV2(_clip(exception.toString()))}',
    ];

    final contextBlock = _formatContext(context);
    if (contextBlock != null) sections.add(contextBlock);

    final fixed = sections.join('\n\n');

    final stack = stackTrace?.toString().trim() ?? '';
    if (stack.isEmpty) return fixed;

    // The stack gets whatever budget the fixed sections left over.
    final stackBudget = telegramMessageLimit - fixed.length - 2;
    final stackBlock =
        _formatStack(stack, maxLines: stackTraceMaxLines, budget: stackBudget);
    return stackBlock == null ? fixed : '$fixed\n\n$stackBlock';
  }

  static String? _formatContext(DwAlertContext? context) {
    if (context == null || context.isEmpty) return null;

    final headline = [
      if (context.platform != null) context.platform!,
      if (context.appVersion != null) 'v${context.appVersion}',
      if (context.userLabel != null) context.userLabel!,
    ].join(' · ');

    final lines = <String>[
      if (headline.isNotEmpty) '🖥 ${escapeMarkdownV2(headline)}',
      if (context.route != null) '📍 ${escapeMarkdownV2(context.route!)}',
      if (context.features.isNotEmpty)
        '🧩 ${escapeMarkdownV2(context.features.join(', '))}',
      if (context.actionLabel != null)
        '⚡ Action: ${escapeMarkdownV2(context.actionLabel!)}',
      if (context.failedCall != null)
        '⚡ Call: ${escapeMarkdownV2(context.failedCall!)}',
      if (context.extra.isNotEmpty)
        '🏷 ${escapeMarkdownV2(context.extra.entries.map((e) => '${e.key}: ${e.value}').join(' · '))}',
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  /// Builds the `📜 *StackTrace*` section: at most [maxLines] lines
  /// (null = all), fitted into [budget] characters. Returns null when even a
  /// single line does not fit — the code block is never left unclosed.
  static String? _formatStack(
    String stack, {
    required int? maxLines,
    required int budget,
  }) {
    final allLines = stack.split('\n');
    final shownCount =
        maxLines == null ? allLines.length : maxLines.clamp(0, allLines.length);
    if (shownCount == 0 || budget < 60) return null;

    final headerSuffix = maxLines != null && allLines.length > maxLines
        ? ' \\(top $maxLines\\)'
        : '';
    var header = '📜 *StackTrace*$headerSuffix\n```\n';
    const footer = '\n```';

    final taken = <String>[];
    var used = header.length + footer.length;
    var truncatedByBudget = false;
    for (final line in allLines.take(shownCount)) {
      final escaped = _escapeCodeBlock(line);
      if (used + escaped.length + 1 > budget) {
        truncatedByBudget = true;
        break;
      }
      taken.add(escaped);
      used += escaped.length + 1;
    }
    if (taken.isEmpty) return null;

    final hiddenCount = allLines.length - taken.length;
    final more = hiddenCount > 0 && (truncatedByBudget || maxLines != null)
        ? '\n\\(\\+$hiddenCount more lines\\)'
        : '';
    return '$header${taken.join('\n')}$footer$more';
  }
}
