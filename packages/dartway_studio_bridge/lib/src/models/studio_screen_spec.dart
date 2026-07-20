/// The screen passport declared in the app's code: functional specification
/// plus product context, keyed by the screen's route path.
///
/// Screens are identified by plain path strings so the bridge stays
/// independent of any router package — the app converts its typed routes to
/// paths when declaring specs.
///
/// Passport texts are plain single-language strings: whatever language the
/// project team writes its specs in is what Studio shows.
class StudioScreenSpec {
  const StudioScreenSpec({
    required this.path,
    this.parentPath,
    required this.title,
    required this.purpose,
    this.discussionQuestions = const [],
  });

  /// Full route path of the screen, e.g. `/schedule/profile`.
  final String path;

  /// Full path of the parent screen (breadcrumb chain), null for roots.
  final String? parentPath;

  final String title;

  /// CJM / business context: why this screen exists.
  final String purpose;

  final List<String> discussionQuestions;

  Map<String, dynamic> toJson() => {
        'path': path,
        if (parentPath != null) 'parentPath': parentPath,
        'title': title,
        'purpose': purpose,
        'discussionQuestions': discussionQuestions,
      };

  factory StudioScreenSpec.fromJson(Map<String, dynamic> json) =>
      StudioScreenSpec(
        path: json['path'] as String? ?? '',
        parentPath: json['parentPath'] as String?,
        title: json['title'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        discussionQuestions: stringListFromJson(json['discussionQuestions']),
      );

  /// Lenient string-list parsing shared by the spec models.
  static List<String> stringListFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is String) item,
      ];
}
