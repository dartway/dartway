// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabBookings => 'My bookings';

  @override
  String get tabNews => 'News';

  @override
  String get tabChat => 'Team chat';

  @override
  String get tabProfile => 'Profile';

  @override
  String helloUser(String name) {
    return 'Hello, $name';
  }

  @override
  String get noUpcomingSessions => 'No upcoming sessions yet';

  @override
  String get sessionFallbackTitle => 'Session';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String withCoach(String name) {
    return 'with $name';
  }

  @override
  String upToPeople(int count) {
    return 'up to $count people';
  }

  @override
  String get book => 'Book';

  @override
  String get cancel => 'Cancel';

  @override
  String get youAreBooked => 'You are booked!';

  @override
  String get bookingCancelled => 'Booking cancelled';

  @override
  String get noBookingsYet => 'No bookings yet — pick a session!';

  @override
  String bookingStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'booked': 'Booked',
      'cancelled': 'Cancelled',
      'attended': 'Attended',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get leaveReview => 'Leave a review';

  @override
  String get thanksForReview => 'Thanks for your review!';

  @override
  String get reviewSheetTitle => 'How was your session?';

  @override
  String get reviewLabel => 'Review';

  @override
  String get reviewHint => 'Tell us what you liked (optional)';

  @override
  String get submitReview => 'Submit review';

  @override
  String get thanksForFeedback => 'Thanks for your feedback!';

  @override
  String get clubNews => 'Club news';

  @override
  String get noNewsYet => 'No news yet — stay tuned!';

  @override
  String get newClubPost => 'New club post';

  @override
  String get postTitleLabel => 'Title';

  @override
  String get postTitleHint => 'What is happening?';

  @override
  String get postContentLabel => 'Content';

  @override
  String get postContentHint => 'Tell the members...';

  @override
  String get publish => 'Publish';

  @override
  String get postPublished => 'Post published!';

  @override
  String get staffOnlyArea => 'This area is for the club team';

  @override
  String get noChatChannels => 'No chat channels yet';

  @override
  String get sayHiToTeam => 'Say hi to the team!';

  @override
  String get messageTheTeam => 'Message the team...';

  @override
  String get ourServices => 'Our services';

  @override
  String get priceListComingSoon => 'The price list is coming soon';

  @override
  String serviceDurationPrice(int minutes, int price) {
    return '$minutes min · $price ₽';
  }

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
      'Counters are live: they update in realtime as members book sessions and staff publishes news.';

  @override
  String get countMembers => 'Members';

  @override
  String get countSessions => 'Sessions';

  @override
  String get countNews => 'News';

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
  String get clubSettings => 'Club settings';

  @override
  String get clubNameLabel => 'Club name';

  @override
  String get saveAction => 'Save';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get noSettingsConfigured => 'No settings configured.';

  @override
  String get networkErrorTryAgain => 'Network error. Please try again.';
}
