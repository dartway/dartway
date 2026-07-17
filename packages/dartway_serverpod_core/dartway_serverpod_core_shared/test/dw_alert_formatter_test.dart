import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';
// DwAlertFormatter is internal — it renders what DwAlerts sends, and is not
// part of the package's public API. Tested through src/ on purpose.
import 'package:dartway_serverpod_core_shared/src/alerts/dw_alert_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('escapeMarkdownV2', () {
    test('escapes every reserved character and backslash', () {
      expect(
        DwAlertFormatter.escapeMarkdownV2(r'a_b*c[d](e)~f`g>h#i+j-k=l|m{n}o.p!\'),
        r'a\_b\*c\[d\]\(e\)\~f\`g\>h\#i\+j\-k\=l\|m\{n\}o\.p\!\\',
      );
    });

    test('leaves plain text untouched', () {
      expect(DwAlertFormatter.escapeMarkdownV2('plain text 123'),
          'plain text 123');
    });
  });

  group('formatErrorReport', () {
    test('template markup survives while values are escaped', () {
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'Failed call: user.save',
        exception: Exception('duplicate key (id=42)'),
        context: const DwAlertContext(route: '/admin/users'),
      );

      expect(message, contains('❌ *Error*')); // template bold is alive
      expect(message, contains('Failed call: user\\.save')); // value escaped
      expect(message, contains('duplicate key \\(id\\=42\\)'));
      expect(message, contains('📍 /admin/users'));
    });

    test('renders all context sections and omits empty ones', () {
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'boom',
        context: const DwAlertContext(
          platform: 'web/android',
          appVersion: '1.4.2',
          userLabel: 'user 42',
          route: '/admin/help',
          features: ['faq-admin', 'admin-shell'],
          actionLabel: 'deleteFaqQuestion',
          extra: {'tenant': 'acme'},
        ),
      );

      expect(message, contains('🖥 web/android · v1\\.4\\.2 · user 42'));
      expect(message, contains('📍 /admin/help'));
      expect(message, contains('🧩 faq\\-admin, admin\\-shell'));
      expect(message, contains('⚡ Action: deleteFaqQuestion'));
      expect(message, contains('🏷 tenant: acme'));
      expect(message, isNot(contains('⚡ Call:')));
      expect(message, isNot(contains('📜'))); // no stack given
    });

    test('empty context object is omitted entirely', () {
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'boom',
        context: const DwAlertContext(),
      );
      expect(message, isNot(contains('🖥')));
      expect(message, isNot(contains('📍')));
    });

    test('stack is trimmed to top N with a hidden-lines marker', () {
      final stack = StackTrace.fromString(
        List.generate(20, (i) => '#$i frame$i').join('\n'),
      );
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'boom',
        stackTrace: stack,
        stackTraceMaxLines: 8,
      );

      expect(message, contains('📜 *StackTrace* \\(top 8\\)'));
      expect(message, contains('#7 frame7'));
      expect(message, isNot(contains('#8 frame8')));
      expect(message, contains('\\(\\+12 more lines\\)'));
      // code block is closed
      expect('```'.allMatches(message).length, 2);
    });

    test('null stackTraceMaxLines keeps the full stack', () {
      final stack = StackTrace.fromString(
        List.generate(12, (i) => '#$i frame$i').join('\n'),
      );
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'boom',
        stackTrace: stack,
        stackTraceMaxLines: null,
      );
      expect(message, contains('#11 frame11'));
      expect(message, isNot(contains('more lines')));
      expect(message, isNot(contains('top')));
    });

    test('total length stays within the Telegram limit', () {
      final hugeStack = StackTrace.fromString(
        List.generate(400, (i) => '#$i ${'x' * 80}').join('\n'),
      );
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'e' * 3000,
        exception: Exception('y' * 3000),
        stackTrace: hugeStack,
        stackTraceMaxLines: null,
      );

      expect(message.length,
          lessThanOrEqualTo(DwAlertFormatter.telegramMessageLimit));
      // if a code block opened, it must be closed
      expect('```'.allMatches(message).length, anyOf(0, 2));
    });

    test('stack lines with backticks and backslashes are code-block safe', () {
      final stack = StackTrace.fromString('#0 weird `line` with \\ slash');
      final message = DwAlertFormatter.formatErrorReport(
        errorMessage: 'boom',
        stackTrace: stack,
      );
      expect(message, contains('weird \\`line\\` with \\\\ slash'));
    });
  });
}
