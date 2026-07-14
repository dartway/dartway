// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabProfile => 'Profile';

  @override
  String get ourServices => 'Our services';

  @override
  String get profileTitle => 'Profile';

  @override
  String get adminPanel => 'Admin panel';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get firstNameLabel => 'First Name';

  @override
  String get firstNameHint => 'Enter your first name';

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
  String get saveChanges => 'Save Changes';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String authStepTitle(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      'greeting': 'Welcome!',
      'registration': 'Step 1 of 3',
      'login': 'Step 1 of 2',
      'registrationConfirmation': 'Step 2 of 3',
      'loginConfirmation': 'Step 2 of 2',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get completeLoginToContinue =>
      'Complete login or registration to continue';

  @override
  String get registrationAction => 'Registration';

  @override
  String get loginAction => 'Login';

  @override
  String get fillRegistrationData => 'Fill registration data';

  @override
  String get nameLabel => 'Name';

  @override
  String get requiredField => 'Required field';

  @override
  String get youMustAgree => 'You must agree';

  @override
  String get agreeTermsPrefix =>
      'I am familiar with and agree to the terms of the';

  @override
  String get offerLink => 'offer,';

  @override
  String get userAgreementLink => 'user agreement,';

  @override
  String get acceptTermsPrefix => 'I accept the terms of the';

  @override
  String get dataPolicyLinkComma => 'data processing policy,';

  @override
  String get iGive => 'I give';

  @override
  String get consentLink => 'consent';

  @override
  String get marketingConsentText =>
      'on receiving informational and promotional mailings, therefore I give';

  @override
  String get dataProcessingConsentText =>
      'on processing personal data in accordance with the';

  @override
  String get dataPolicyLink => 'data processing policy';

  @override
  String get continueAction => 'Continue';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get stillNoAccount => 'Still no account? ';

  @override
  String get enterSmsCode => 'Enter the code from SMS';

  @override
  String sentCodeToNumber(String phone) {
    return 'Sent 6-digit code to number\n$phone';
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
      'Counters are live: they update in realtime as the data changes.';

  @override
  String get countMembers => 'Members';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchHint => 'Name or phone';

  @override
  String get allRoles => 'All roles';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'client': 'Client',
      'staff': 'Staff',
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
  String confirmChangeRole(String name, String role) {
    return 'Change the role of $name to $role?';
  }

  @override
  String get appSettings => 'App settings';

  @override
  String get appNameLabel => 'App name';

  @override
  String get saveAction => 'Save';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get noSettingsConfigured => 'No settings configured.';

  @override
  String get networkErrorTryAgain => 'Network error. Please try again.';

  @override
  String get tabHome => 'Home';

  @override
  String get homeTitle => 'Home';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name!';
  }

  @override
  String homeAppNameFromDatabase(String appName) {
    return 'App name from the database: $appName';
  }

  @override
  String get homeNoAppName =>
      'No app name configured yet — set it in the admin panel.';

  @override
  String get homeNextStepTitle => 'Your first feature';

  @override
  String get homeNextStepBody =>
      'Describe a model, give it a DwCrudConfig on the server, and read it with ref.watchModelList in a widget. No endpoints to write.';

  @override
  String get countSettings => 'Settings';
}
