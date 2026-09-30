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

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// No description provided for @tabBookings.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get tabBookings;

  /// No description provided for @tabNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get tabNews;

  /// No description provided for @tabChat.
  ///
  /// In en, this message translates to:
  /// **'Team chat'**
  String get tabChat;

  /// No description provided for @tabWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get tabWorkouts;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloUser(String name);

  /// No description provided for @noUpcomingSessions.
  ///
  /// In en, this message translates to:
  /// **'No upcoming sessions yet'**
  String get noUpcomingSessions;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @withCoach.
  ///
  /// In en, this message translates to:
  /// **'with {name}'**
  String withCoach(String name);

  /// No description provided for @spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{left} of {capacity} spots left'**
  String spotsLeft(int left, int capacity);

  /// No description provided for @sessionFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get sessionFull;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @youAreBooked.
  ///
  /// In en, this message translates to:
  /// **'You are booked!'**
  String get youAreBooked;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get bookingCancelled;

  /// No description provided for @noBookingsYet.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet — pick a session!'**
  String get noBookingsYet;

  /// No description provided for @bookingStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, booked{Booked} cancelled{Cancelled} attended{Attended} other{—}}'**
  String bookingStatus(String status);

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBooking;

  /// No description provided for @leaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get leaveReview;

  /// No description provided for @thanksForReview.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review!'**
  String get thanksForReview;

  /// No description provided for @reviewSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your session?'**
  String get reviewSheetTitle;

  /// No description provided for @reviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewLabel;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you liked (optional)'**
  String get reviewHint;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get submitReview;

  /// No description provided for @thanksForFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get thanksForFeedback;

  /// No description provided for @clubNews.
  ///
  /// In en, this message translates to:
  /// **'Club news'**
  String get clubNews;

  /// No description provided for @notifyAboutNews.
  ///
  /// In en, this message translates to:
  /// **'Notify me about news'**
  String get notifyAboutNews;

  /// No description provided for @noNewsYet.
  ///
  /// In en, this message translates to:
  /// **'No news yet — stay tuned!'**
  String get noNewsYet;

  /// No description provided for @newClubPost.
  ///
  /// In en, this message translates to:
  /// **'New club post'**
  String get newClubPost;

  /// No description provided for @postTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get postTitleLabel;

  /// No description provided for @postTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What is happening?'**
  String get postTitleHint;

  /// No description provided for @postContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get postContentLabel;

  /// No description provided for @postContentHint.
  ///
  /// In en, this message translates to:
  /// **'Tell the members...'**
  String get postContentHint;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @postPublished.
  ///
  /// In en, this message translates to:
  /// **'Post published!'**
  String get postPublished;

  /// No description provided for @staffOnlyArea.
  ///
  /// In en, this message translates to:
  /// **'This area is for the club team'**
  String get staffOnlyArea;

  /// No description provided for @noChatChannels.
  ///
  /// In en, this message translates to:
  /// **'No chat channels yet'**
  String get noChatChannels;

  /// No description provided for @sayHiToTeam.
  ///
  /// In en, this message translates to:
  /// **'Say hi to the team!'**
  String get sayHiToTeam;

  /// No description provided for @messageTheTeam.
  ///
  /// In en, this message translates to:
  /// **'Message the team...'**
  String get messageTheTeam;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendMessage;

  /// No description provided for @chatUnreadDivider.
  ///
  /// In en, this message translates to:
  /// **'Unread messages'**
  String get chatUnreadDivider;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chatEdited;

  /// No description provided for @chatDeletedMember.
  ///
  /// In en, this message translates to:
  /// **'Member who left'**
  String get chatDeletedMember;

  /// No description provided for @chatDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleted message'**
  String get chatDeletedMessage;

  /// No description provided for @chatPinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get chatPinnedMessage;

  /// No description provided for @chatPinnedPosition.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String chatPinnedPosition(int index, int count);

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEdit;

  /// No description provided for @chatCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get chatCopyText;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// No description provided for @chatPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatPin;

  /// No description provided for @chatUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatUnpin;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete the message?'**
  String get chatDeleteQuestion;

  /// No description provided for @chatDeleteExplanation.
  ///
  /// In en, this message translates to:
  /// **'It disappears for the whole team. Replies keep a note that it was deleted.'**
  String get chatDeleteExplanation;

  /// No description provided for @chatReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String chatReplyTo(String name);

  /// No description provided for @chatEditingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing the message'**
  String get chatEditingMessage;

  /// No description provided for @chatAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get chatAttachFile;

  /// No description provided for @chatAttachmentLimit.
  ///
  /// In en, this message translates to:
  /// **'At most {max} files in one message'**
  String chatAttachmentLimit(int max);

  /// No description provided for @chatFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} is larger than {megabytes} MB'**
  String chatFileTooLarge(String name, int megabytes);

  /// No description provided for @chatUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} did not upload'**
  String chatUploadFailed(String name);

  /// No description provided for @chatPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhoto;

  /// No description provided for @chatSearch.
  ///
  /// In en, this message translates to:
  /// **'Search the chat'**
  String get chatSearch;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchHint;

  /// No description provided for @chatSearchNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get chatSearchNothing;

  /// No description provided for @chatSearchPosition.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String chatSearchPosition(int index, int count);

  /// No description provided for @chatSearchOlder.
  ///
  /// In en, this message translates to:
  /// **'Older match'**
  String get chatSearchOlder;

  /// No description provided for @chatSearchNewer.
  ///
  /// In en, this message translates to:
  /// **'Newer match'**
  String get chatSearchNewer;

  /// No description provided for @chatCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get chatCloseSearch;

  /// No description provided for @chatJumpToNewest.
  ///
  /// In en, this message translates to:
  /// **'To the newest messages'**
  String get chatJumpToNewest;

  /// No description provided for @chatMessageGone.
  ///
  /// In en, this message translates to:
  /// **'That message is no longer in the chat'**
  String get chatMessageGone;

  /// No description provided for @ourServices.
  ///
  /// In en, this message translates to:
  /// **'Our services'**
  String get ourServices;

  /// No description provided for @priceListComingSoon.
  ///
  /// In en, this message translates to:
  /// **'The price list is coming soon'**
  String get priceListComingSoon;

  /// No description provided for @serviceDurationPrice.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · {price} ₽'**
  String serviceDurationPrice(int minutes, int price);

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

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidPhoneNumber;

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

  /// No description provided for @whatIsYourName.
  ///
  /// In en, this message translates to:
  /// **'What is your name?'**
  String get whatIsYourName;

  /// No description provided for @whatIsYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'The club team will see it on your bookings'**
  String get whatIsYourNameHint;

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
  /// **'The server counts these, and they change live as the club does — no reload.'**
  String get countersLiveHint;

  /// No description provided for @countMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get countMembers;

  /// No description provided for @countSessions.
  ///
  /// In en, this message translates to:
  /// **'Upcoming sessions'**
  String get countSessions;

  /// No description provided for @countNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get countNews;

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

  /// No description provided for @clubSettings.
  ///
  /// In en, this message translates to:
  /// **'Club settings'**
  String get clubSettings;

  /// No description provided for @clubNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get clubNameLabel;

  /// No description provided for @bookingEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Booking open'**
  String get bookingEnabledLabel;

  /// No description provided for @supportPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Support phone'**
  String get supportPhoneLabel;

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

  /// No description provided for @refusalGeneric.
  ///
  /// In en, this message translates to:
  /// **'The request was refused.'**
  String get refusalGeneric;

  /// No description provided for @refusalTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a title.'**
  String get refusalTitleRequired;

  /// No description provided for @refusalTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Add the text.'**
  String get refusalTextRequired;

  /// No description provided for @refusalDurationNotPositive.
  ///
  /// In en, this message translates to:
  /// **'The duration must be longer than zero.'**
  String get refusalDurationNotPositive;

  /// No description provided for @refusalPriceNegative.
  ///
  /// In en, this message translates to:
  /// **'The price cannot be negative.'**
  String get refusalPriceNegative;

  /// No description provided for @refusalCapacityTooSmall.
  ///
  /// In en, this message translates to:
  /// **'A session needs at least one spot.'**
  String get refusalCapacityTooSmall;

  /// No description provided for @refusalSessionInPast.
  ///
  /// In en, this message translates to:
  /// **'A session cannot be scheduled in the past.'**
  String get refusalSessionInPast;

  /// No description provided for @refusalSessionStarted.
  ///
  /// In en, this message translates to:
  /// **'This session has already started.'**
  String get refusalSessionStarted;

  /// No description provided for @refusalNoSpotsLeft.
  ///
  /// In en, this message translates to:
  /// **'No spots left on this session.'**
  String get refusalNoSpotsLeft;

  /// No description provided for @refusalAlreadyBooked.
  ///
  /// In en, this message translates to:
  /// **'You are already booked on this session.'**
  String get refusalAlreadyBooked;

  /// No description provided for @refusalBookingNotActive.
  ///
  /// In en, this message translates to:
  /// **'This booking is no longer active.'**
  String get refusalBookingNotActive;

  /// No description provided for @refusalRatingOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Pick a rating from 1 to 5.'**
  String get refusalRatingOutOfRange;

  /// No description provided for @refusalReviewNeedsAttendance.
  ///
  /// In en, this message translates to:
  /// **'A visit can be reviewed once it has taken place.'**
  String get refusalReviewNeedsAttendance;

  /// No description provided for @refusalAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'You have already reviewed this visit.'**
  String get refusalAlreadyReviewed;

  /// No description provided for @refusalMessageEmpty.
  ///
  /// In en, this message translates to:
  /// **'The message is empty.'**
  String get refusalMessageEmpty;

  /// No description provided for @refusalMessageTooLong.
  ///
  /// In en, this message translates to:
  /// **'The message is longer than {max} characters.'**
  String refusalMessageTooLong(int max);

  /// No description provided for @refusalTooManyAttachments.
  ///
  /// In en, this message translates to:
  /// **'At most {max} files in one message.'**
  String refusalTooManyAttachments(int max);

  /// No description provided for @refusalEditWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'A message can no longer be edited a day after it was sent.'**
  String get refusalEditWindowClosed;

  /// No description provided for @refusalSearchQueryTooShort.
  ///
  /// In en, this message translates to:
  /// **'Type at least {min} characters to search.'**
  String refusalSearchQueryTooShort(int min);

  /// No description provided for @refusalClubNameRequired.
  ///
  /// In en, this message translates to:
  /// **'The club name cannot be blank.'**
  String get refusalClubNameRequired;

  /// No description provided for @refusalFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get refusalFirstNameRequired;

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

  /// No description provided for @refusalInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get refusalInvalidPhone;

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

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update the app'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Install the latest one to keep using the club.'**
  String get updateRequiredBody;

  /// No description provided for @serverMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'The app cannot reach its server'**
  String get serverMismatchTitle;

  /// No description provided for @serverMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'This app and the club\'s server speak different versions. We are on it — please try again later.'**
  String get serverMismatchBody;

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

  /// No description provided for @refusalFileNotOwned.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be used here.'**
  String get refusalFileNotOwned;

  /// No description provided for @refusalUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The file did not upload. Please try again.'**
  String get refusalUploadFailed;

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

  /// No description provided for @analyticsOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get analyticsOrderLabel;

  /// No description provided for @analyticsOrder.
  ///
  /// In en, this message translates to:
  /// **'{order, select, largestFirst{Largest first} byLabel{By value: 1, 2, … 10} other{—}}'**
  String analyticsOrder(String order);

  /// No description provided for @analyticsPieNeedsProperty.
  ///
  /// In en, this message translates to:
  /// **'A pie shows events split by a property: choose one under “Split by”.'**
  String get analyticsPieNeedsProperty;

  /// No description provided for @workoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workoutsTitle;

  /// No description provided for @workoutVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get workoutVideo;

  /// No description provided for @workoutAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get workoutAudio;

  /// No description provided for @mediaPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPlay;

  /// No description provided for @mediaPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mediaPause;

  /// No description provided for @mediaSkipBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get mediaSkipBack;

  /// No description provided for @mediaSkipForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get mediaSkipForward;

  /// No description provided for @mediaMute.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get mediaMute;

  /// No description provided for @mediaSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get mediaSpeed;

  /// No description provided for @mediaFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get mediaFullscreen;

  /// No description provided for @mediaClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get mediaClose;

  /// No description provided for @mediaFailed.
  ///
  /// In en, this message translates to:
  /// **'This could not be played.'**
  String get mediaFailed;

  /// No description provided for @mediaUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get mediaUpNext;

  /// No description provided for @mediaNextIn.
  ///
  /// In en, this message translates to:
  /// **'Next in {seconds} s'**
  String mediaNextIn(int seconds);

  /// No description provided for @mediaStayHere.
  ///
  /// In en, this message translates to:
  /// **'Stay on this one'**
  String get mediaStayHere;
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
