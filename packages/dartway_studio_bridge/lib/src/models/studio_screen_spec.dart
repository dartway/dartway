import 'studio_text.dart';

/// The screen passport declared in the app's code: functional specification
/// plus product context, keyed by the screen's route path.
///
/// Screens are identified by plain path strings so the bridge stays
/// independent of any router package — the app converts its typed routes to
/// paths when declaring specs.
class StudioScreenSpec {
  const StudioScreenSpec({
    required this.path,
    this.parentPath,
    required this.title,
    required this.purpose,
    this.featureSpec = const [],
    this.discussionQuestions = const [],
  });

  /// Full route path of the screen, e.g. `/schedule/profile`.
  final String path;

  /// Full path of the parent screen (breadcrumb chain), null for roots.
  final String? parentPath;

  final StudioText title;

  /// CJM / business context: why this screen exists.
  final StudioText purpose;

  /// Which framework capability each feature of the screen demonstrates.
  final List<StudioText> featureSpec;

  final List<StudioText> discussionQuestions;

  Map<String, dynamic> toJson() => {
        'path': path,
        if (parentPath != null) 'parentPath': parentPath,
        'title': title.toJson(),
        'purpose': purpose.toJson(),
        'featureSpec': [for (final text in featureSpec) text.toJson()],
        'discussionQuestions': [
          for (final text in discussionQuestions) text.toJson(),
        ],
      };

  factory StudioScreenSpec.fromJson(Map<String, dynamic> json) =>
      StudioScreenSpec(
        path: json['path'] as String? ?? '',
        parentPath: json['parentPath'] as String?,
        title: StudioText.fromJson(
          json['title'] as Map<String, dynamic>? ?? const {},
        ),
        purpose: StudioText.fromJson(
          json['purpose'] as Map<String, dynamic>? ?? const {},
        ),
        featureSpec: StudioText.listFromJson(json['featureSpec']),
        discussionQuestions:
            StudioText.listFromJson(json['discussionQuestions']),
      );
}
