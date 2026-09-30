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
  String get connectionOnline => 'online';

  @override
  String get connectionConnecting => 'connecting';

  @override
  String get connectionOffline => 'offline';

  @override
  String get connectionIncompatible => 'update the app';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabBookings => 'My bookings';

  @override
  String get tabNews => 'News';

  @override
  String get tabChat => 'Team chat';

  @override
  String get tabWorkouts => 'Workouts';

  @override
  String get tabProfile => 'Profile';

  @override
  String helloUser(String name) {
    return 'Hello, $name';
  }

  @override
  String get noUpcomingSessions => 'No upcoming sessions yet';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String withCoach(String name) {
    return 'with $name';
  }

  @override
  String spotsLeft(int left, int capacity) {
    return '$left of $capacity spots left';
  }

  @override
  String get sessionFull => 'Full';

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
  String get notifyAboutNews => 'Notify me about news';

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
  String get sendMessage => 'Send';

  @override
  String get chatUnreadDivider => 'Unread messages';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatDeletedMember => 'Member who left';

  @override
  String get chatDeletedMessage => 'Deleted message';

  @override
  String get chatPinnedMessage => 'Pinned message';

  @override
  String chatPinnedPosition(int index, int count) {
    return '$index of $count';
  }

  @override
  String get chatReply => 'Reply';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatCopyText => 'Copy text';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatPin => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatDeleteQuestion => 'Delete the message?';

  @override
  String get chatDeleteExplanation =>
      'It disappears for the whole team. Replies keep a note that it was deleted.';

  @override
  String chatReplyTo(String name) {
    return 'Reply to $name';
  }

  @override
  String get chatEditingMessage => 'Editing the message';

  @override
  String get chatAttachFile => 'Attach a file';

  @override
  String chatAttachmentLimit(int max) {
    return 'At most $max files in one message';
  }

  @override
  String chatFileTooLarge(String name, int megabytes) {
    return '$name is larger than $megabytes MB';
  }

  @override
  String chatUploadFailed(String name) {
    return '$name did not upload';
  }

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatSearch => 'Search the chat';

  @override
  String get chatSearchHint => 'Search messages';

  @override
  String get chatSearchNothing => 'Nothing found';

  @override
  String chatSearchPosition(int index, int count) {
    return '$index of $count';
  }

  @override
  String get chatSearchOlder => 'Older match';

  @override
  String get chatSearchNewer => 'Newer match';

  @override
  String get chatCloseSearch => 'Close search';

  @override
  String get chatJumpToNewest => 'To the newest messages';

  @override
  String get chatMessageGone => 'That message is no longer in the chat';

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
  String get phoneLabel => 'Phone';

  @override
  String get requiredField => 'Required field';

  @override
  String get invalidPhoneNumber => 'Invalid number';

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
  String get whatIsYourName => 'What is your name?';

  @override
  String get whatIsYourNameHint => 'The club team will see it on your bookings';

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
      'The server counts these, and they change live as the club does — no reload.';

  @override
  String get countMembers => 'Members';

  @override
  String get countSessions => 'Upcoming sessions';

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
  String get clubSettings => 'Club settings';

  @override
  String get clubNameLabel => 'Club name';

  @override
  String get bookingEnabledLabel => 'Booking open';

  @override
  String get supportPhoneLabel => 'Support phone';

  @override
  String get saveAction => 'Save';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get refusalGeneric => 'The request was refused.';

  @override
  String get refusalTitleRequired => 'Add a title.';

  @override
  String get refusalTextRequired => 'Add the text.';

  @override
  String get refusalDurationNotPositive =>
      'The duration must be longer than zero.';

  @override
  String get refusalPriceNegative => 'The price cannot be negative.';

  @override
  String get refusalCapacityTooSmall => 'A session needs at least one spot.';

  @override
  String get refusalSessionInPast =>
      'A session cannot be scheduled in the past.';

  @override
  String get refusalSessionStarted => 'This session has already started.';

  @override
  String get refusalNoSpotsLeft => 'No spots left on this session.';

  @override
  String get refusalAlreadyBooked => 'You are already booked on this session.';

  @override
  String get refusalBookingNotActive => 'This booking is no longer active.';

  @override
  String get refusalRatingOutOfRange => 'Pick a rating from 1 to 5.';

  @override
  String get refusalReviewNeedsAttendance =>
      'A visit can be reviewed once it has taken place.';

  @override
  String get refusalAlreadyReviewed => 'You have already reviewed this visit.';

  @override
  String get refusalMessageEmpty => 'The message is empty.';

  @override
  String refusalMessageTooLong(int max) {
    return 'The message is longer than $max characters.';
  }

  @override
  String refusalTooManyAttachments(int max) {
    return 'At most $max files in one message.';
  }

  @override
  String get refusalEditWindowClosed =>
      'A message can no longer be edited a day after it was sent.';

  @override
  String refusalSearchQueryTooShort(int min) {
    return 'Type at least $min characters to search.';
  }

  @override
  String get refusalClubNameRequired => 'The club name cannot be blank.';

  @override
  String get refusalFirstNameRequired => 'Enter your name.';

  @override
  String get refusalForbidden => 'You are not allowed to do this.';

  @override
  String get refusalNotFound => 'It no longer exists.';

  @override
  String get refusalConflict => 'This changed a moment ago — please try again.';

  @override
  String get refusalInvalid => 'Check what you entered.';

  @override
  String get refusalInvalidPhone => 'Enter a valid phone number.';

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
  String get updateRequiredTitle => 'Update the app';

  @override
  String get updateRequiredBody =>
      'This version of the app is no longer supported. Install the latest one to keep using the club.';

  @override
  String get serverMismatchTitle => 'The app cannot reach its server';

  @override
  String get serverMismatchBody =>
      'This app and the club\'s server speak different versions. We are on it — please try again later.';

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
  String get refusalFileNotOwned => 'This file cannot be used here.';

  @override
  String get refusalUploadFailed =>
      'The file did not upload. Please try again.';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsNoDashboards =>
      'No dashboards yet. Create one and put on it the numbers you watch.';

  @override
  String get analyticsNewDashboard => 'New dashboard';

  @override
  String get analyticsDashboardTitle => 'Dashboard title';

  @override
  String get analyticsRenameDashboard => 'Rename dashboard';

  @override
  String get analyticsDeleteDashboard => 'Delete dashboard';

  @override
  String analyticsDeleteDashboardConfirmation(String title) {
    return 'Delete the dashboard “$title”? Its widgets go with it; the events stay.';
  }

  @override
  String get analyticsEditDashboard => 'Edit dashboard';

  @override
  String get analyticsDoneEditing => 'Done';

  @override
  String get analyticsAddWidget => 'Add widget';

  @override
  String get analyticsEditWidget => 'Edit widget';

  @override
  String get analyticsRemoveWidget => 'Remove widget';

  @override
  String get analyticsMoveWidgetBack => 'Move back';

  @override
  String get analyticsMoveWidgetForward => 'Move forward';

  @override
  String get analyticsNoWidgets => 'This dashboard has no widgets yet.';

  @override
  String analyticsLastDays(int days) {
    return '$days days';
  }

  @override
  String get analyticsPickDates => 'Dates…';

  @override
  String analyticsWidgetType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'indicator': 'Number',
      'bar': 'Bars',
      'pie': 'Pie',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get analyticsWidgetTitle => 'Title';

  @override
  String get analyticsEvent => 'Event';

  @override
  String get analyticsEveryEvent => 'Any event';

  @override
  String analyticsEventWithCount(String name, int count) {
    return '$name ($count)';
  }

  @override
  String get analyticsMetricLabel => 'Count';

  @override
  String analyticsMetric(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'events': 'Events',
      'accounts': 'People (signed-in accounts)',
      'installs': 'Devices (installs)',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get analyticsFilters => 'Only where';

  @override
  String get analyticsAddFilter => 'Add a condition';

  @override
  String get analyticsFilterProperty => 'Property';

  @override
  String get analyticsFilterValue => 'equals';

  @override
  String get analyticsRemoveFilter => 'Remove the condition';

  @override
  String get analyticsBreakdownLabel => 'Split by';

  @override
  String get analyticsBreakdownNone => 'Nothing';

  @override
  String analyticsBucket(String bucket) {
    String _temp0 = intl.Intl.selectLogic(bucket, {
      'day': 'Day',
      'week': 'Week',
      'month': 'Month',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String analyticsByProperty(String key) {
    return 'Property “$key”';
  }

  @override
  String get analyticsTopValues => 'Values shown';

  @override
  String get analyticsComparePrevious => 'Compare with the previous period';

  @override
  String get analyticsVsPrevious => 'vs the previous period';

  @override
  String get analyticsOther => 'Other';

  @override
  String get analyticsNotSet => 'Not set';

  @override
  String get analyticsNoData => 'Nothing recorded in this period.';

  @override
  String get refusalAnalyticsBatchInvalid =>
      'The app recorded events the server cannot store.';

  @override
  String get refusalAnalyticsReportInvalid =>
      'This report cannot be built: check its event, properties and dates.';

  @override
  String get refusalAnalyticsDashboardInvalid =>
      'Check the dashboard: it needs a title, and at most 12 widgets, each with a title.';

  @override
  String get analyticsOrderLabel => 'Order';

  @override
  String analyticsOrder(String order) {
    String _temp0 = intl.Intl.selectLogic(order, {
      'largestFirst': 'Largest first',
      'byLabel': 'By value: 1, 2, … 10',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get analyticsPieNeedsProperty =>
      'A pie shows events split by a property: choose one under “Split by”.';

  @override
  String get workoutsTitle => 'Workouts';

  @override
  String get workoutVideo => 'Video';

  @override
  String get workoutAudio => 'Audio';

  @override
  String get mediaPlay => 'Play';

  @override
  String get mediaPause => 'Pause';

  @override
  String get mediaSkipBack => 'Back';

  @override
  String get mediaSkipForward => 'Forward';

  @override
  String get mediaMute => 'Sound';

  @override
  String get mediaSpeed => 'Speed';

  @override
  String get mediaFullscreen => 'Fullscreen';

  @override
  String get mediaClose => 'Close';

  @override
  String get mediaFailed => 'This could not be played.';

  @override
  String get mediaUpNext => 'Up next';

  @override
  String mediaNextIn(int seconds) {
    return 'Next in $seconds s';
  }

  @override
  String get mediaStayHere => 'Stay on this one';
}
