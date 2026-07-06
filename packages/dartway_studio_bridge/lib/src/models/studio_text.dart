/// Languages the Studio passport content is authored in.
enum StudioLanguage { en, ru }

/// A bilingual text snippet: screen passports serve both the public
/// documentation (EN) and localized product presentations (RU).
class StudioText {
  const StudioText(this.en, this.ru);

  final String en;
  final String ru;

  String resolve(StudioLanguage language) =>
      language == StudioLanguage.ru ? ru : en;

  Map<String, dynamic> toJson() => {'en': en, 'ru': ru};

  factory StudioText.fromJson(Map<String, dynamic> json) => StudioText(
        json['en'] as String? ?? '',
        json['ru'] as String? ?? '',
      );

  static List<StudioText> listFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is Map<String, dynamic>) StudioText.fromJson(item),
      ];
}
