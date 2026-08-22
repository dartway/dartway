/// A refusal: the operation did not happen because a rule said no, and
/// [message] is what the rule said.
///
/// Thrown where a failure would otherwise be, because the code that meets it
/// is the code that catches exceptions — but it is not one, and everything
/// downstream is meant to tell the difference:
///
/// - `dw.action` shows [message] to the user instead of the action's generic
///   `onErrorNotification`. The text was written for this exact case; "Could
///   not delete" was written for all of them.
/// - the framework's own error policy does not alert it. A rule doing its job
///   is not an incident, and a channel that receives one for every refused
///   click stops being read.
/// - an app's own `DwConfig.onErrorReport` still receives it, and sorts it out
///   with one type check — `if (report.error is DwRefusal) return;` — rather
///   than by comparing the message against strings it hopes the server still
///   uses.
///
/// Most of them arrive from the server: a `DwApiResponse` carrying
/// `isRefusal`, raised by `DwRepository.processApiResponse`. Throwing one from
/// the app's own code is the same statement made locally — "this is the user's
/// answer, not a bug" — and gets the same treatment.
///
/// ```dart
/// if (file.lengthSync() > maxUpload) {
///   throw const DwRefusal('This file is larger than 10 MB');
/// }
/// ```
///
/// **[message] is shown to a user**, so write it for one: no identifiers, no
/// class names, no stack of an underlying error. A refusal nobody can act on
/// is a failure wearing the wrong type.
class DwRefusal implements Exception {
  const DwRefusal(this.message);

  /// What the rule said, in the words it was written in — the text that
  /// reaches the screen unedited.
  final String message;

  /// The message alone: this is the one exception whose `toString` is meant
  /// for a person, and it lands in notifications and report titles as such.
  @override
  String toString() => message;
}
