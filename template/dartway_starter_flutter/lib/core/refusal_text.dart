import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'app_l10n.dart';

/// Every refusal code the app can be answered with, by its wire code.
final Map<String, DwRefusalCode> _codes = {
  for (final code in <DwRefusalCode>[
    ...DartwayStarterRefusal.values,
    ...DwCoreRefusal.values,
    ...DwAuthRefusal.values,
    ...DwUploadRefusal.values,
  ])
    code.code: code,
};

/// The sentence a refusal is shown as. A refusal carries a code and
/// parameters, never text: this is where the app turns them into words.
///
/// Every switch below is exhaustive, so a code added to
/// [DartwayStarterRefusal] or to one of the framework's enums does not compile
/// until it has a text. A code none of them knows — a newer server — still
/// gets a sentence.
String refusalText(AppLocalizations l10n, DwCallRefusal refusal) =>
    switch (_codes[refusal.code]) {
      final DartwayStarterRefusal code => _appText(l10n, code),
      final DwCoreRefusal code => _coreText(l10n, code, refusal),
      final DwAuthRefusal code => _authText(l10n, code),
      final DwUploadRefusal code => _uploadText(l10n, code, refusal),
      _ => l10n.refusalGeneric,
    };

String _appText(AppLocalizations l10n, DartwayStarterRefusal code) =>
    switch (code) {
      DartwayStarterRefusal.consentsRequired => l10n.refusalConsentsRequired,
      DartwayStarterRefusal.signUpClosed => l10n.refusalSignUpClosed,
      DartwayStarterRefusal.firstNameRequired => l10n.refusalFirstNameRequired,
      DartwayStarterRefusal.settingKeyUnknown => l10n.refusalSettingKeyUnknown,
      DartwayStarterRefusal.ownRoleLocked => l10n.refusalOwnRoleLocked,
    };

String _coreText(
  AppLocalizations l10n,
  DwCoreRefusal code,
  DwCallRefusal refusal,
) => switch (code) {
  DwCoreRefusal.forbidden => l10n.refusalForbidden,
  DwCoreRefusal.notFound => l10n.refusalNotFound,
  DwCoreRefusal.conflict => l10n.refusalConflict,
  // The field says what was wrong; signing in is where this app meets it.
  DwCoreRefusal.invalid => switch (refusal.field) {
    'identifier' => l10n.refusalInvalidIdentifier,
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

String _authText(AppLocalizations l10n, DwAuthRefusal code) => switch (code) {
  DwAuthRefusal.identifierTaken => l10n.refusalIdentifierTaken,
};

String _uploadText(
  AppLocalizations l10n,
  DwUploadRefusal code,
  DwCallRefusal refusal,
) => switch (code) {
  DwUploadRefusal.tooLarge => l10n.refusalUploadTooLarge(
    ((int.tryParse(refusal.params['maxBytes'] ?? '') ?? 0) / (1024 * 1024))
        .ceil(),
  ),
  DwUploadRefusal.typeRejected => l10n.refusalUploadTypeRejected,
  DwUploadRefusal.notOwned => l10n.refusalFileNotOwned,
  // What went wrong between the app and the storage is not the user's to
  // untangle: the upload is simply tried again.
  DwUploadRefusal.purposeUnknown ||
  DwUploadRefusal.missing ||
  DwUploadRefusal.mismatch ||
  DwUploadRefusal.expired => l10n.refusalUploadFailed,
};
