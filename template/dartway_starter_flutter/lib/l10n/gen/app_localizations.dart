import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @ourServices.
  ///
  /// In en, this message translates to:
  /// **'Our services'**
  String get ourServices;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminPanel;

  /// No description provided for @signOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutAction;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstNameLabel;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get firstNameHint;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @genderNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get genderNotSpecified;

  /// No description provided for @genderValue.
  ///
  /// In en, this message translates to:
  /// **'{gender, select, male{Male} female{Female} other{—}}'**
  String genderValue(String gender);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @authStepTitle.
  ///
  /// In en, this message translates to:
  /// **'{step, select, greeting{Welcome!} registration{Step 1 of 3} login{Step 1 of 2} registrationConfirmation{Step 2 of 3} loginConfirmation{Step 2 of 2} other{}}'**
  String authStepTitle(String step);

  /// No description provided for @completeLoginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Complete login or registration to continue'**
  String get completeLoginToContinue;

  /// No description provided for @registrationAction.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registrationAction;

  /// No description provided for @loginAction.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginAction;

  /// No description provided for @fillRegistrationData.
  ///
  /// In en, this message translates to:
  /// **'Fill registration data'**
  String get fillRegistrationData;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @youMustAgree.
  ///
  /// In en, this message translates to:
  /// **'You must agree'**
  String get youMustAgree;

  /// No description provided for @agreeTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I am familiar with and agree to the terms of the'**
  String get agreeTermsPrefix;

  /// No description provided for @offerLink.
  ///
  /// In en, this message translates to:
  /// **'offer,'**
  String get offerLink;

  /// No description provided for @userAgreementLink.
  ///
  /// In en, this message translates to:
  /// **'user agreement,'**
  String get userAgreementLink;

  /// No description provided for @acceptTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms of the'**
  String get acceptTermsPrefix;

  /// No description provided for @dataPolicyLinkComma.
  ///
  /// In en, this message translates to:
  /// **'data processing policy,'**
  String get dataPolicyLinkComma;

  /// No description provided for @iGive.
  ///
  /// In en, this message translates to:
  /// **'I give'**
  String get iGive;

  /// No description provided for @consentLink.
  ///
  /// In en, this message translates to:
  /// **'consent'**
  String get consentLink;

  /// No description provided for @marketingConsentText.
  ///
  /// In en, this message translates to:
  /// **'on receiving informational and promotional mailings, therefore I give'**
  String get marketingConsentText;

  /// No description provided for @dataProcessingConsentText.
  ///
  /// In en, this message translates to:
  /// **'on processing personal data in accordance with the'**
  String get dataProcessingConsentText;

  /// No description provided for @dataPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'data processing policy'**
  String get dataPolicyLink;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @stillNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Still no account? '**
  String get stillNoAccount;

  /// No description provided for @enterSmsCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from SMS'**
  String get enterSmsCode;

  /// No description provided for @sentCodeToNumber.
  ///
  /// In en, this message translates to:
  /// **'Sent 6-digit code to number\n{phone}'**
  String sentCodeToNumber(String phone);

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// No description provided for @adminSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get adminSettings;

  /// No description provided for @backToApp.
  ///
  /// In en, this message translates to:
  /// **'Back to the app'**
  String get backToApp;

  /// No description provided for @countersLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Counters are live: they update in realtime as the data changes.'**
  String get countersLiveHint;

  /// No description provided for @countMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get countMembers;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Name or phone'**
  String get searchHint;

  /// No description provided for @allRoles.
  ///
  /// In en, this message translates to:
  /// **'All roles'**
  String get allRoles;

  /// No description provided for @roleName.
  ///
  /// In en, this message translates to:
  /// **'{role, select, client{Client} staff{Staff} admin{Admin} other{—}}'**
  String roleName(String role);

  /// No description provided for @noMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get noMembersYet;

  /// No description provided for @noMembersMatch.
  ///
  /// In en, this message translates to:
  /// **'No members match.'**
  String get noMembersMatch;

  /// No description provided for @confirmChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change the role of {name} to {role}?'**
  String confirmChangeRole(String name, String role);

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettings;

  /// No description provided for @appNameLabel.
  ///
  /// In en, this message translates to:
  /// **'App name'**
  String get appNameLabel;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @noSettingsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No settings configured.'**
  String get noSettingsConfigured;

  /// No description provided for @networkErrorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get networkErrorTryAgain;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @homeAppNameFromDatabase.
  ///
  /// In en, this message translates to:
  /// **'App name from the database: {appName}'**
  String homeAppNameFromDatabase(String appName);

  /// No description provided for @homeNoAppName.
  ///
  /// In en, this message translates to:
  /// **'No app name configured yet — set it in the admin panel.'**
  String get homeNoAppName;

  /// No description provided for @homeNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first feature'**
  String get homeNextStepTitle;

  /// No description provided for @homeNextStepBody.
  ///
  /// In en, this message translates to:
  /// **'Describe a model, give it a DwCrudConfig on the server, and read it with ref.watchModelList in a widget. No endpoints to write.'**
  String get homeNextStepBody;

  /// No description provided for @countSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get countSettings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
