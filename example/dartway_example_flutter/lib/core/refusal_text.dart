import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'app_l10n.dart';

/// Every refusal code the app can be answered with, by its wire code.
final Map<String, DwRefusalCode> _codes = {
  for (final code in <DwRefusalCode>[
    ...ExampleRefusal.values,
    ...DwCoreRefusal.values,
  ])
    code.code: code,
};

/// The sentence a refusal is shown as. A refusal carries a code and
/// parameters, never text: this is where the app turns them into words.
///
/// Both switches below are exhaustive, so a code added to [ExampleRefusal] or
/// to the framework's [DwCoreRefusal] does not compile until it has a text.
/// A code neither knows — a newer server — still gets a sentence.
String refusalText(AppLocalizations l10n, DwCallRefusal refusal) =>
    switch (_codes[refusal.code]) {
      final ExampleRefusal code => _exampleText(l10n, code, refusal),
      final DwCoreRefusal code => _coreText(l10n, code, refusal),
      _ => l10n.refusalGeneric,
    };

String _exampleText(
  AppLocalizations l10n,
  ExampleRefusal code,
  DwCallRefusal refusal,
) {
  int param(String name, int fallback) =>
      int.tryParse(refusal.params[name] ?? '') ?? fallback;
  return switch (code) {
    ExampleRefusal.titleRequired => l10n.refusalTitleRequired,
    ExampleRefusal.textRequired => l10n.refusalTextRequired,
    ExampleRefusal.durationNotPositive => l10n.refusalDurationNotPositive,
    ExampleRefusal.priceNegative => l10n.refusalPriceNegative,
    ExampleRefusal.capacityTooSmall => l10n.refusalCapacityTooSmall,
    ExampleRefusal.sessionInPast => l10n.refusalSessionInPast,
    ExampleRefusal.sessionStarted => l10n.refusalSessionStarted,
    ExampleRefusal.noSpotsLeft => l10n.refusalNoSpotsLeft,
    ExampleRefusal.alreadyBooked => l10n.refusalAlreadyBooked,
    ExampleRefusal.bookingNotActive => l10n.refusalBookingNotActive,
    ExampleRefusal.ratingOutOfRange => l10n.refusalRatingOutOfRange,
    ExampleRefusal.reviewNeedsAttendance => l10n.refusalReviewNeedsAttendance,
    ExampleRefusal.alreadyReviewed => l10n.refusalAlreadyReviewed,
    ExampleRefusal.messageEmpty => l10n.refusalMessageEmpty,
    ExampleRefusal.messageTooLong => l10n.refusalMessageTooLong(
      param('max', ChatMessage.maxTextLength),
    ),
    ExampleRefusal.tooManyAttachments => l10n.refusalTooManyAttachments(
      param('max', ChatMessage.maxAttachments),
    ),
    ExampleRefusal.editWindowClosed => l10n.refusalEditWindowClosed,
    ExampleRefusal.searchQueryTooShort => l10n.refusalSearchQueryTooShort(
      param('min', SearchChatMessages.minQueryLength),
    ),
    ExampleRefusal.settingKeyUnknown => l10n.refusalSettingKeyUnknown,
    ExampleRefusal.firstNameRequired => l10n.refusalFirstNameRequired,
  };
}

String _coreText(
  AppLocalizations l10n,
  DwCoreRefusal code,
  DwCallRefusal refusal,
) => switch (code) {
  DwCoreRefusal.forbidden => l10n.refusalForbidden,
  DwCoreRefusal.notFound => l10n.refusalNotFound,
  DwCoreRefusal.conflict => l10n.refusalConflict,
  // The field says what was wrong; sign-in is where this app meets it.
  DwCoreRefusal.invalid => switch (refusal.field) {
    'identifier' => l10n.refusalInvalidPhone,
    'code' => switch (int.tryParse(refusal.params['attemptsLeft'] ?? '')) {
      final attemptsLeft? => l10n.refusalWrongCodeAttemptsLeft(attemptsLeft),
      null => l10n.refusalWrongCode,
    },
    _ => l10n.refusalInvalid,
  },
  DwCoreRefusal.unknownChannel => l10n.refusalUnknownChannel,
  DwCoreRefusal.tooManyRequests => switch (refusal.retryAfter) {
    final wait? => l10n.refusalTooManyRequestsRetryIn(wait.inSeconds),
    null => l10n.refusalTooManyRequests,
  },
  DwCoreRefusal.codeExpired => l10n.refusalCodeExpired,
  // Shown by the update page over the whole app; this text is for a place
  // that renders a refusal on its own.
  DwCoreRefusal.updateRequired => l10n.updateRequiredBody,
  DwCoreRefusal.protocolUnsupported => l10n.serverMismatchBody,
};
