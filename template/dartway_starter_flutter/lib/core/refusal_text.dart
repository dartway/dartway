import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'app_l10n.dart';

/// The words for a refusal the server answered with, in this language.
extension AppRefusalText on AppLocalizations {
  /// Every refusal code the app can be answered with, by its wire code.
  static final Map<String, DwRefusalCode> _codes = {
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
  String refusalText(DwCallRefusal refusal) => switch (_codes[refusal.code]) {
    final DartwayStarterRefusal code => _appText(code),
    final DwCoreRefusal code => _coreText(code, refusal),
    final DwAuthRefusal code => _authText(code),
    final DwUploadRefusal code => _uploadText(code, refusal),
    _ => refusalGeneric,
  };

  String _appText(DartwayStarterRefusal code) => switch (code) {
    DartwayStarterRefusal.consentsRequired => refusalConsentsRequired,
    DartwayStarterRefusal.signUpClosed => refusalSignUpClosed,
    DartwayStarterRefusal.firstNameRequired => refusalFirstNameRequired,
    DartwayStarterRefusal.settingKeyUnknown => refusalSettingKeyUnknown,
    DartwayStarterRefusal.ownRoleLocked => refusalOwnRoleLocked,
  };

  String _coreText(DwCoreRefusal code, DwCallRefusal refusal) => switch (code) {
    DwCoreRefusal.forbidden => refusalForbidden,
    DwCoreRefusal.notFound => refusalNotFound,
    DwCoreRefusal.conflict => refusalConflict,
    // The field says what was wrong; signing in is where this app meets it.
    DwCoreRefusal.invalid => switch (refusal.field) {
      'identifier' => refusalInvalidIdentifier,
      'code' => switch (int.tryParse(refusal.params['attemptsLeft'] ?? '')) {
        final attemptsLeft? => refusalWrongCodeAttemptsLeft(attemptsLeft),
        null => refusalWrongCode,
      },
      _ => refusalInvalid,
    },
    DwCoreRefusal.unknownChannel => refusalUnknownChannel,
    DwCoreRefusal.tooManyRequests => switch (refusal.retryAfter) {
      final wait? => refusalTooManyRequestsRetryIn(wait.inSeconds),
      null => refusalTooManyRequests,
    },
    DwCoreRefusal.codeExpired => refusalCodeExpired,
    // Shown by the update page over the whole app; this text is for a place
    // that renders a refusal on its own.
    DwCoreRefusal.updateRequired => updateRequiredBody,
    DwCoreRefusal.protocolUnsupported => serverMismatchBody,
  };

  String _authText(DwAuthRefusal code) => switch (code) {
    DwAuthRefusal.identifierTaken => refusalIdentifierTaken,
  };

  String _uploadText(DwUploadRefusal code, DwCallRefusal refusal) =>
      switch (code) {
        DwUploadRefusal.tooLarge => refusalUploadTooLarge(
          ((int.tryParse(refusal.params['maxBytes'] ?? '') ?? 0) /
                  (1024 * 1024))
              .ceil(),
        ),
        DwUploadRefusal.typeRejected => refusalUploadTypeRejected,
        DwUploadRefusal.notOwned => refusalFileNotOwned,
        // What went wrong between the app and the storage is not the user's to
        // untangle: the upload is simply tried again.
        DwUploadRefusal.purposeUnknown ||
        DwUploadRefusal.missing ||
        DwUploadRefusal.mismatch ||
        DwUploadRefusal.expired => refusalUploadFailed,
      };
}
