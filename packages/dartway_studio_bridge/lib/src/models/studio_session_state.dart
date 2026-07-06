/// The app's current session as far as Studio needs to know: whether someone
/// is signed in, which declared persona it maps to, and whether a persona
/// switch is in flight.
class StudioSessionState {
  const StudioSessionState({
    required this.isSignedIn,
    this.activePersonaId,
    this.displayLabel,
    this.isBusy = false,
  });

  static const signedOut = StudioSessionState(isSignedIn: false);

  final bool isSignedIn;

  /// Id of the matching [StudioPersonaSpec], null when the signed-in user is
  /// not one of the declared personas.
  final String? activePersonaId;

  /// Label to show for the current user (persona label or profile name).
  final String? displayLabel;

  /// True while the app is executing a persona switch.
  final bool isBusy;

  Map<String, dynamic> toJson() => {
        'isSignedIn': isSignedIn,
        if (activePersonaId != null) 'activePersonaId': activePersonaId,
        if (displayLabel != null) 'displayLabel': displayLabel,
        'isBusy': isBusy,
      };

  factory StudioSessionState.fromJson(Map<String, dynamic> json) =>
      StudioSessionState(
        isSignedIn: json['isSignedIn'] as bool? ?? false,
        activePersonaId: json['activePersonaId'] as String?,
        displayLabel: json['displayLabel'] as String?,
        isBusy: json['isBusy'] as bool? ?? false,
      );
}
