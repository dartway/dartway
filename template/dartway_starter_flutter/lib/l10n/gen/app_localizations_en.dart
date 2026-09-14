// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loadFailed =>
      'Could not load this — check your connection and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get actionFailed => 'Something went wrong. Please try again.';

  @override
  String get notImplementedYet => 'Not implemented yet';

  @override
  String get connectionOnline => 'online';

  @override
  String get connectionConnecting => 'connecting';

  @override
  String get connectionOffline => 'offline';

  @override
  String get connectionIncompatible => 'update the app';

  @override
  String get requiredField => 'Required field';

  @override
  String get continueAction => 'Continue';

  @override
  String get saveAction => 'Save';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get tabHome => 'Home';

  @override
  String get tabProfile => 'Profile';

  @override
  String get homeTitle => 'Home';

  @override
  String helloUser(String name) {
    return 'Hello, $name';
  }

  @override
  String homeAppName(String appName) {
    return 'You are in $appName';
  }

  @override
  String get homeLiveHint =>
      'The name above is a setting stored on the server: change it in the admin panel and every open screen follows, without a reload.';

  @override
  String get homeNextStepTitle => 'Your first feature';

  @override
  String get homeNextStepBody =>
      'Declare a data object and a request in the shared package, a row and a handler on the server, run dartway generate, and watch the request with dw.request in a widget.';

  @override
  String authStepTitle(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      'identifier': 'Sign in',
      'code': 'Confirm',
      'consents': 'New account',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get authIntro =>
      'Sign in with your phone number or e-mail. If we do not know it yet, signing in creates your account.';

  @override
  String identifierKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'phone': 'Phone',
      'email': 'E-mail',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '+1 555 010 0199';

  @override
  String get invalidPhoneNumber => 'Enter a number of 10 to 15 digits';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get invalidEmail => 'Enter an e-mail address';

  @override
  String get getCodeAction => 'Get a code';

  @override
  String get codeTitle => 'Enter the code';

  @override
  String codeSentTo(String identifier) {
    return 'We sent a code to $identifier';
  }

  @override
  String resendCodeIn(int seconds) {
    return 'A new code in $seconds s';
  }

  @override
  String get resendCodeAction => 'Send a new code';

  @override
  String get changeIdentifierAction => 'Use another phone or e-mail';

  @override
  String consentsIntro(String identifier) {
    return '$identifier is new here. Tell us your name and accept the terms to create your account.';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get termsConsentPrefix => 'I accept the ';

  @override
  String get termsLink => 'terms of use';

  @override
  String get termsConsentMiddle => ' and the ';

  @override
  String get privacyLink => 'privacy policy';

  @override
  String get marketingConsent => 'Send me news and offers';

  @override
  String get youMustAgree => 'Accept the terms to continue';

  @override
  String get createAccountAction => 'Create account';

  @override
  String get whatIsYourName => 'What is your name?';

  @override
  String get whatIsYourNameHint =>
      'This is how others in the app will see you.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get adminPanel => 'Admin panel';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get firstNameHint => 'Enter your first name';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get firstNameRequired => 'First name is required';

  @override
  String get genderLabel => 'Gender';

  @override
  String get genderNotSpecified => 'Not specified';

  @override
  String genderValue(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': 'Male',
      'female': 'Female',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profilePhotoHint => 'Tap the photo to change it';

  @override
  String get profilePhotoUpdated => 'Photo updated';

  @override
  String get profilePhotoRemove => 'Remove photo';

  @override
  String get profilePhotoRemoved => 'Photo removed';

  @override
  String get identitySectionTitle => 'Signing in';

  @override
  String get identityNotSet => 'Not added';

  @override
  String get identityAddAction => 'Add';

  @override
  String get identityChangeAction => 'Change';

  @override
  String identitySheetTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'phone': 'Your new phone number',
      'email': 'Your new e-mail',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get identitySheetIntro =>
      'We will send a code to confirm it. Until then nothing changes, and you stay signed in.';

  @override
  String get identityConfirmAction => 'Confirm';

  @override
  String identitySaved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'phone': 'Phone number saved',
      'email': 'E-mail saved',
      'other': 'Saved',
    });
    return '$_temp0';
  }

  @override
  String get adminDashboard => 'Dashboard';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminSettings => 'Settings';

  @override
  String get backToApp => 'Back to the app';

  @override
  String get countersLiveHint =>
      'The server counts these, and they change live — no reload.';

  @override
  String get countMembers => 'Members';

  @override
  String get countAdmins => 'Admins';

  @override
  String get countMarketingOptIns => 'News subscribers';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchHint => 'Name, phone or e-mail';

  @override
  String get allRoles => 'All roles';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'user': 'User',
      'admin': 'Admin',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get noMembersYet => 'No members yet.';

  @override
  String get noMembersMatch => 'No members match.';

  @override
  String membersPage(int page, int pageCount, int total) {
    return 'Page $page of $pageCount · $total members';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String confirmChangeRole(String name, String role) {
    return 'Change the role of $name to $role?';
  }

  @override
  String get roleLabel => 'Role';

  @override
  String get ownRoleHint => 'Your own role is changed by another admin.';

  @override
  String get userCardNotFound => 'There is no such user.';

  @override
  String userCardJoined(String date) {
    return 'Joined $date';
  }

  @override
  String userCardTermsAccepted(String date) {
    return 'Terms accepted $date';
  }

  @override
  String get userCardTermsNotAccepted =>
      'Created by a tool: no terms were accepted';

  @override
  String userCardMarketing(String agreed) {
    String _temp0 = intl.Intl.selectLogic(agreed, {
      'true': 'Subscribed to news and offers',
      'other': 'Not subscribed to news and offers',
    });
    return '$_temp0';
  }

  @override
  String get userCardIdentifiers => 'Signs in with';

  @override
  String identifierVerified(String date) {
    return 'confirmed $date';
  }

  @override
  String get identifierNotVerified => 'never confirmed';

  @override
  String get appSettingsTitle => 'App settings';

  @override
  String get appNameLabel => 'App name';

  @override
  String get signUpEnabledLabel => 'New accounts can sign up';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get refusalGeneric => 'The request was refused.';

  @override
  String get refusalConsentsRequired =>
      'Accept the terms to create an account.';

  @override
  String get refusalSignUpClosed => 'New accounts cannot sign up right now.';

  @override
  String get refusalFirstNameRequired => 'Enter your name.';

  @override
  String get refusalSettingKeyUnknown => 'This setting does not exist.';

  @override
  String get refusalOwnRoleLocked =>
      'Your own role is changed by another admin.';

  @override
  String get refusalForbidden => 'You are not allowed to do this.';

  @override
  String get refusalNotFound => 'It no longer exists.';

  @override
  String get refusalConflict => 'This changed a moment ago — please try again.';

  @override
  String get refusalInvalid => 'Check what you entered.';

  @override
  String get refusalInvalidIdentifier =>
      'Enter a valid phone number or e-mail.';

  @override
  String get refusalWrongCode => 'Wrong code.';

  @override
  String refusalWrongCodeAttemptsLeft(int attemptsLeft) {
    return 'Wrong code. Attempts left: $attemptsLeft';
  }

  @override
  String get refusalCodeExpired =>
      'This code no longer works — request a new one.';

  @override
  String get refusalTooManyRequests =>
      'Too many attempts. Please wait a little.';

  @override
  String refusalTooManyRequestsRetryIn(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String get refusalUnknownChannel =>
      'This version of the app does not match the server — please update it.';

  @override
  String get refusalIdentifierTaken =>
      'This is already used by another account.';

  @override
  String refusalUploadTooLarge(int megabytes) {
    return 'The file is too large: at most $megabytes MB.';
  }

  @override
  String get refusalUploadTypeRejected => 'This type of file is not accepted.';

  @override
  String get refusalUploadFailed =>
      'The file did not upload. Please try again.';

  @override
  String get refusalFileNotOwned => 'This file cannot be used here.';

  @override
  String get updateRequiredTitle => 'Update the app';

  @override
  String get updateRequiredBody =>
      'This version of the app is no longer supported. Install the latest one to keep using it.';

  @override
  String get serverMismatchTitle => 'The app cannot reach its server';

  @override
  String get serverMismatchBody =>
      'This app and its server speak different versions. We are on it — please try again later.';
}
