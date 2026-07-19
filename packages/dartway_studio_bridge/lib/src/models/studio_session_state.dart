/// The app's current session as far as Studio needs to know: whether someone
/// is signed in, who it is (by the app's own identifier), and whether a
/// requested sign-in is still in flight.
class StudioSessionState {
  const StudioSessionState({
    required this.isSignedIn,
    this.userIdentifier,
    this.displayLabel,
    this.isBusy = false,
  });

  static const signedOut = StudioSessionState(isSignedIn: false);

  final bool isSignedIn;

  /// The signed-in user's identifier in the form the app's auth uses (phone,
  /// email). Studio matches it against its own configured demo personas — the
  /// app knows nothing about personas.
  final String? userIdentifier;

  /// Label to show for the current user (e.g. profile name).
  final String? displayLabel;

  /// True while the app is executing a requested sign-in or sign-out.
  final bool isBusy;

  Map<String, dynamic> toJson() => {
        'isSignedIn': isSignedIn,
        if (userIdentifier != null) 'userIdentifier': userIdentifier,
        if (displayLabel != null) 'displayLabel': displayLabel,
        'isBusy': isBusy,
      };

  factory StudioSessionState.fromJson(Map<String, dynamic> json) =>
      StudioSessionState(
        isSignedIn: json['isSignedIn'] as bool? ?? false,
        userIdentifier: json['userIdentifier'] as String?,
        displayLabel: json['displayLabel'] as String?,
        isBusy: json['isBusy'] as bool? ?? false,
      );
}
