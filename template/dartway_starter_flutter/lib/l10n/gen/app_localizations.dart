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

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this — check your connection and try again.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get actionFailed;

  /// No description provided for @notImplementedYet.
  ///
  /// In en, this message translates to:
  /// **'Not implemented yet'**
  String get notImplementedYet;

  /// No description provided for @connectionOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get connectionOnline;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get connectionConnecting;

  /// No description provided for @connectionOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get connectionOffline;

  /// No description provided for @connectionIncompatible.
  ///
  /// In en, this message translates to:
  /// **'update the app'**
  String get connectionIncompatible;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloUser(String name);

  /// No description provided for @homeAppName.
  ///
  /// In en, this message translates to:
  /// **'You are in {appName}'**
  String homeAppName(String appName);

  /// No description provided for @homeLiveHint.
  ///
  /// In en, this message translates to:
  /// **'The name above is a setting stored on the server: change it in the admin panel and every open screen follows, without a reload.'**
  String get homeLiveHint;

  /// No description provided for @homeNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first feature'**
  String get homeNextStepTitle;

  /// No description provided for @homeNextStepBody.
  ///
  /// In en, this message translates to:
  /// **'Declare a data object and a request in the shared package, a row and a handler on the server, run dartway generate, and watch the request with dw.request in a widget.'**
  String get homeNextStepBody;

  /// No description provided for @authStepTitle.
  ///
  /// In en, this message translates to:
  /// **'{step, select, identifier{Sign in} code{Confirm} consents{New account} other{}}'**
  String authStepTitle(String step);

  /// No description provided for @authIntro.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone number or e-mail. If we do not know it yet, signing in creates your account.'**
  String get authIntro;

  /// No description provided for @identifierKind.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, phone{Phone} email{E-mail} other{—}}'**
  String identifierKind(String kind);

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+1 555 010 0199'**
  String get phoneHint;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of 10 to 15 digits'**
  String get invalidPhoneNumber;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an e-mail address'**
  String get invalidEmail;

  /// No description provided for @getCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Get a code'**
  String get getCodeAction;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeTitle;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {identifier}'**
  String codeSentTo(String identifier);

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'A new code in {seconds} s'**
  String resendCodeIn(int seconds);

  /// No description provided for @resendCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get resendCodeAction;

  /// No description provided for @changeIdentifierAction.
  ///
  /// In en, this message translates to:
  /// **'Use another phone or e-mail'**
  String get changeIdentifierAction;

  /// No description provided for @consentsIntro.
  ///
  /// In en, this message translates to:
  /// **'{identifier} is new here. Tell us your name and accept the terms to create your account.'**
  String consentsIntro(String identifier);

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @termsConsentPrefix.
  ///
  /// In en, this message translates to:
  /// **'I accept the '**
  String get termsConsentPrefix;

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'terms of use'**
  String get termsLink;

  /// No description provided for @termsConsentMiddle.
  ///
  /// In en, this message translates to:
  /// **' and the '**
  String get termsConsentMiddle;

  /// No description provided for @privacyLink.
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get privacyLink;

  /// No description provided for @marketingConsent.
  ///
  /// In en, this message translates to:
  /// **'Send me news and offers'**
  String get marketingConsent;

  /// No description provided for @youMustAgree.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms to continue'**
  String get youMustAgree;

  /// No description provided for @createAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountAction;

  /// No description provided for @whatIsYourName.
  ///
  /// In en, this message translates to:
  /// **'What is your name?'**
  String get whatIsYourName;

  /// No description provided for @whatIsYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'This is how others in the app will see you.'**
  String get whatIsYourNameHint;

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

  /// The button that deletes the signed-in account for good.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountAction;

  /// Asked before the account is deleted.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and everything in it? This cannot be undone.'**
  String get deleteAccountConfirmation;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstNameLabel;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get firstNameHint;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastNameLabel;

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

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profilePhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the photo to change it'**
  String get profilePhotoHint;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get profilePhotoUpdated;

  /// No description provided for @profilePhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profilePhotoRemove;

  /// No description provided for @profilePhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get profilePhotoRemoved;

  /// No description provided for @identitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get identitySectionTitle;

  /// No description provided for @identityNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get identityNotSet;

  /// No description provided for @identityAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get identityAddAction;

  /// No description provided for @identityChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get identityChangeAction;

  /// No description provided for @identitySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, phone{Your new phone number} email{Your new e-mail} other{}}'**
  String identitySheetTitle(String kind);

  /// No description provided for @identitySheetIntro.
  ///
  /// In en, this message translates to:
  /// **'We will send a code to confirm it. Until then nothing changes, and you stay signed in.'**
  String get identitySheetIntro;

  /// No description provided for @identityConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get identityConfirmAction;

  /// No description provided for @identitySaved.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, phone{Phone number saved} email{E-mail saved} other{Saved}}'**
  String identitySaved(String kind);

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
  /// **'The server counts these, and they change live — no reload.'**
  String get countersLiveHint;

  /// No description provided for @countMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get countMembers;

  /// No description provided for @countAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get countAdmins;

  /// No description provided for @countMarketingOptIns.
  ///
  /// In en, this message translates to:
  /// **'News subscribers'**
  String get countMarketingOptIns;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, phone or e-mail'**
  String get searchHint;

  /// No description provided for @allRoles.
  ///
  /// In en, this message translates to:
  /// **'All roles'**
  String get allRoles;

  /// No description provided for @roleName.
  ///
  /// In en, this message translates to:
  /// **'{role, select, user{User} admin{Admin} other{—}}'**
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

  /// No description provided for @membersPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pageCount} · {total} members'**
  String membersPage(int page, int pageCount, int total);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @confirmChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change the role of {name} to {role}?'**
  String confirmChangeRole(String name, String role);

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @ownRoleHint.
  ///
  /// In en, this message translates to:
  /// **'Your own role is changed by another admin.'**
  String get ownRoleHint;

  /// No description provided for @userCardNotFound.
  ///
  /// In en, this message translates to:
  /// **'There is no such user.'**
  String get userCardNotFound;

  /// No description provided for @userCardJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String userCardJoined(String date);

  /// No description provided for @userCardTermsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Terms accepted {date}'**
  String userCardTermsAccepted(String date);

  /// No description provided for @userCardTermsNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Created by a tool: no terms were accepted'**
  String get userCardTermsNotAccepted;

  /// No description provided for @userCardMarketing.
  ///
  /// In en, this message translates to:
  /// **'{agreed, select, true{Subscribed to news and offers} other{Not subscribed to news and offers}}'**
  String userCardMarketing(String agreed);

  /// No description provided for @userCardIdentifiers.
  ///
  /// In en, this message translates to:
  /// **'Signs in with'**
  String get userCardIdentifiers;

  /// No description provided for @identifierVerified.
  ///
  /// In en, this message translates to:
  /// **'confirmed {date}'**
  String identifierVerified(String date);

  /// No description provided for @identifierNotVerified.
  ///
  /// In en, this message translates to:
  /// **'never confirmed'**
  String get identifierNotVerified;

  /// No description provided for @appSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettingsTitle;

  /// No description provided for @appNameLabel.
  ///
  /// In en, this message translates to:
  /// **'App name'**
  String get appNameLabel;

  /// No description provided for @signUpEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'New accounts can sign up'**
  String get signUpEnabledLabel;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @refusalGeneric.
  ///
  /// In en, this message translates to:
  /// **'The request was refused.'**
  String get refusalGeneric;

  /// No description provided for @refusalConsentsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms to create an account.'**
  String get refusalConsentsRequired;

  /// No description provided for @refusalSignUpClosed.
  ///
  /// In en, this message translates to:
  /// **'New accounts cannot sign up right now.'**
  String get refusalSignUpClosed;

  /// No description provided for @refusalFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get refusalFirstNameRequired;

  /// No description provided for @refusalSettingKeyUnknown.
  ///
  /// In en, this message translates to:
  /// **'This setting does not exist.'**
  String get refusalSettingKeyUnknown;

  /// No description provided for @refusalOwnRoleLocked.
  ///
  /// In en, this message translates to:
  /// **'Your own role is changed by another admin.'**
  String get refusalOwnRoleLocked;

  /// No description provided for @refusalForbidden.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do this.'**
  String get refusalForbidden;

  /// No description provided for @refusalNotFound.
  ///
  /// In en, this message translates to:
  /// **'It no longer exists.'**
  String get refusalNotFound;

  /// No description provided for @refusalConflict.
  ///
  /// In en, this message translates to:
  /// **'This changed a moment ago — please try again.'**
  String get refusalConflict;

  /// No description provided for @refusalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check what you entered.'**
  String get refusalInvalid;

  /// No description provided for @refusalInvalidIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number or e-mail.'**
  String get refusalInvalidIdentifier;

  /// No description provided for @refusalWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code.'**
  String get refusalWrongCode;

  /// No description provided for @refusalWrongCodeAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Attempts left: {attemptsLeft}'**
  String refusalWrongCodeAttemptsLeft(int attemptsLeft);

  /// No description provided for @refusalCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code no longer works — request a new one.'**
  String get refusalCodeExpired;

  /// No description provided for @refusalTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a little.'**
  String get refusalTooManyRequests;

  /// No description provided for @refusalTooManyRequestsRetryIn.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s.'**
  String refusalTooManyRequestsRetryIn(int seconds);

  /// No description provided for @refusalUnknownChannel.
  ///
  /// In en, this message translates to:
  /// **'This version of the app does not match the server — please update it.'**
  String get refusalUnknownChannel;

  /// No description provided for @refusalIdentifierTaken.
  ///
  /// In en, this message translates to:
  /// **'This is already used by another account.'**
  String get refusalIdentifierTaken;

  /// No description provided for @refusalUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large: at most {megabytes} MB.'**
  String refusalUploadTooLarge(int megabytes);

  /// No description provided for @refusalUploadTypeRejected.
  ///
  /// In en, this message translates to:
  /// **'This type of file is not accepted.'**
  String get refusalUploadTypeRejected;

  /// No description provided for @refusalUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The file did not upload. Please try again.'**
  String get refusalUploadFailed;

  /// No description provided for @refusalFileNotOwned.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be used here.'**
  String get refusalFileNotOwned;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update the app'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Install the latest one to keep using it.'**
  String get updateRequiredBody;

  /// No description provided for @serverMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'The app cannot reach its server'**
  String get serverMismatchTitle;

  /// No description provided for @serverMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'This app and its server speak different versions. We are on it — please try again later.'**
  String get serverMismatchBody;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsNoDashboards.
  ///
  /// In en, this message translates to:
  /// **'No dashboards yet. Create one and put on it the numbers you watch.'**
  String get analyticsNoDashboards;

  /// No description provided for @analyticsNewDashboard.
  ///
  /// In en, this message translates to:
  /// **'New dashboard'**
  String get analyticsNewDashboard;

  /// No description provided for @analyticsDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard title'**
  String get analyticsDashboardTitle;

  /// No description provided for @analyticsRenameDashboard.
  ///
  /// In en, this message translates to:
  /// **'Rename dashboard'**
  String get analyticsRenameDashboard;

  /// No description provided for @analyticsDeleteDashboard.
  ///
  /// In en, this message translates to:
  /// **'Delete dashboard'**
  String get analyticsDeleteDashboard;

  /// No description provided for @analyticsDeleteDashboardConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete the dashboard “{title}”? Its widgets go with it; the events stay.'**
  String analyticsDeleteDashboardConfirmation(String title);

  /// No description provided for @analyticsEditDashboard.
  ///
  /// In en, this message translates to:
  /// **'Edit dashboard'**
  String get analyticsEditDashboard;

  /// No description provided for @analyticsDoneEditing.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get analyticsDoneEditing;

  /// No description provided for @analyticsAddWidget.
  ///
  /// In en, this message translates to:
  /// **'Add widget'**
  String get analyticsAddWidget;

  /// No description provided for @analyticsEditWidget.
  ///
  /// In en, this message translates to:
  /// **'Edit widget'**
  String get analyticsEditWidget;

  /// No description provided for @analyticsRemoveWidget.
  ///
  /// In en, this message translates to:
  /// **'Remove widget'**
  String get analyticsRemoveWidget;

  /// No description provided for @analyticsMoveWidgetBack.
  ///
  /// In en, this message translates to:
  /// **'Move back'**
  String get analyticsMoveWidgetBack;

  /// No description provided for @analyticsMoveWidgetForward.
  ///
  /// In en, this message translates to:
  /// **'Move forward'**
  String get analyticsMoveWidgetForward;

  /// No description provided for @analyticsNoWidgets.
  ///
  /// In en, this message translates to:
  /// **'This dashboard has no widgets yet.'**
  String get analyticsNoWidgets;

  /// No description provided for @analyticsLastDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String analyticsLastDays(int days);

  /// No description provided for @analyticsPickDates.
  ///
  /// In en, this message translates to:
  /// **'Dates…'**
  String get analyticsPickDates;

  /// No description provided for @analyticsWidgetType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, indicator{Number} bar{Bars} pie{Pie} other{—}}'**
  String analyticsWidgetType(String type);

  /// No description provided for @analyticsWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get analyticsWidgetTitle;

  /// No description provided for @analyticsEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get analyticsEvent;

  /// No description provided for @analyticsEveryEvent.
  ///
  /// In en, this message translates to:
  /// **'Any event'**
  String get analyticsEveryEvent;

  /// No description provided for @analyticsEventWithCount.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count})'**
  String analyticsEventWithCount(String name, int count);

  /// No description provided for @analyticsMetricLabel.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get analyticsMetricLabel;

  /// No description provided for @analyticsMetric.
  ///
  /// In en, this message translates to:
  /// **'{metric, select, events{Events} accounts{People (signed-in accounts)} installs{Devices (installs)} other{—}}'**
  String analyticsMetric(String metric);

  /// No description provided for @analyticsFilters.
  ///
  /// In en, this message translates to:
  /// **'Only where'**
  String get analyticsFilters;

  /// No description provided for @analyticsAddFilter.
  ///
  /// In en, this message translates to:
  /// **'Add a condition'**
  String get analyticsAddFilter;

  /// No description provided for @analyticsFilterProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get analyticsFilterProperty;

  /// No description provided for @analyticsFilterValue.
  ///
  /// In en, this message translates to:
  /// **'equals'**
  String get analyticsFilterValue;

  /// No description provided for @analyticsRemoveFilter.
  ///
  /// In en, this message translates to:
  /// **'Remove the condition'**
  String get analyticsRemoveFilter;

  /// No description provided for @analyticsBreakdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Split by'**
  String get analyticsBreakdownLabel;

  /// No description provided for @analyticsBreakdownNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get analyticsBreakdownNone;

  /// No description provided for @analyticsBucket.
  ///
  /// In en, this message translates to:
  /// **'{bucket, select, day{Day} week{Week} month{Month} other{—}}'**
  String analyticsBucket(String bucket);

  /// No description provided for @analyticsByProperty.
  ///
  /// In en, this message translates to:
  /// **'Property “{key}”'**
  String analyticsByProperty(String key);

  /// No description provided for @analyticsTopValues.
  ///
  /// In en, this message translates to:
  /// **'Values shown'**
  String get analyticsTopValues;

  /// No description provided for @analyticsComparePrevious.
  ///
  /// In en, this message translates to:
  /// **'Compare with the previous period'**
  String get analyticsComparePrevious;

  /// No description provided for @analyticsVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'vs the previous period'**
  String get analyticsVsPrevious;

  /// No description provided for @analyticsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get analyticsOther;

  /// No description provided for @analyticsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get analyticsNotSet;

  /// No description provided for @analyticsNoData.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded in this period.'**
  String get analyticsNoData;

  /// No description provided for @refusalAnalyticsBatchInvalid.
  ///
  /// In en, this message translates to:
  /// **'The app recorded events the server cannot store.'**
  String get refusalAnalyticsBatchInvalid;

  /// No description provided for @refusalAnalyticsReportInvalid.
  ///
  /// In en, this message translates to:
  /// **'This report cannot be built: check its event, properties and dates.'**
  String get refusalAnalyticsReportInvalid;

  /// No description provided for @refusalAnalyticsDashboardInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the dashboard: it needs a title, and at most 12 widgets, each with a title.'**
  String get refusalAnalyticsDashboardInvalid;
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
