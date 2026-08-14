/// Wire model of a product feature present on the current screen, as the app
/// reports it over the bridge.
///
/// The bridge does not know *how* the app discovers its features — DartWay
/// apps typically map `DwFeatureSpec`s collected by `DwFeature.scanMounted()`
/// (package `dartway_flutter`) onto this model in their bridge binding, but
/// any source works.
///
/// The fields split by audience, and Studio shows them accordingly: [title],
/// [purpose] and [behaviors] are what a client reads, while [requirements],
/// [implementationNotes] and [knownIssues] are written for the team.
class StudioFeatureInfo {
  const StudioFeatureInfo({
    required this.id,
    required this.title,
    this.purpose,
    this.behaviors = const [],
    this.requirements = const [],
    this.implementationNotes = const [],
    this.knownIssues = const [],
  });

  /// Stable id — deduplicates a feature reported by multiple widget instances,
  /// and the name feedback and tracker items refer it by.
  final String id;

  final String title;

  /// Why the feature exists for the user; absent for parts that serve a screen
  /// rather than carrying a purpose of their own.
  final String? purpose;

  /// What the feature observably does — one checkable statement per entry.
  final List<String> behaviors;

  /// What it must honour, imposed from outside the feature.
  final List<String> requirements;

  /// What the code cannot say about itself: reasons, traps, decisions the team
  /// should not have to re-open. Technical side only.
  ///
  /// The test the app side applies when filling this in — *would it still be
  /// worth reading after the feature is rewritten?* — keeps out descriptions of
  /// how the code is put together, which go stale silently.
  final List<String> implementationNotes;

  /// What is wrong in the feature and worth taking into work. Studio filters
  /// on this to show which features carry open questions.
  final List<String> knownIssues;

  /// Whether the feature carries anything worth taking into work.
  bool get hasKnownIssues => knownIssues.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (purpose != null) 'purpose': purpose,
        if (behaviors.isNotEmpty) 'behaviors': behaviors,
        if (requirements.isNotEmpty) 'requirements': requirements,
        if (implementationNotes.isNotEmpty)
          'implementationNotes': implementationNotes,
        if (knownIssues.isNotEmpty) 'knownIssues': knownIssues,
      };

  /// Parsing stays lenient: an app built against an older bridge sends neither
  /// the new lists nor `purpose`, and an app built against a newer one may send
  /// fields this Studio has never heard of. Both must keep working.
  factory StudioFeatureInfo.fromJson(Map<String, dynamic> json) =>
      StudioFeatureInfo(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        purpose: json['purpose'] as String?,
        behaviors: stringListFromJson(json['behaviors']),
        requirements: stringListFromJson(json['requirements']),
        implementationNotes: stringListFromJson(json['implementationNotes']),
        knownIssues: stringListFromJson(json['knownIssues']),
      );

  static List<StudioFeatureInfo> listFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is Map<String, dynamic>) StudioFeatureInfo.fromJson(item),
      ];

  /// Lenient string-list parsing, shared with the other spec models.
  static List<String> stringListFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is String) item,
      ];
}
