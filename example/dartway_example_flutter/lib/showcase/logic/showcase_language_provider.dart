import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'specs/showcase_screen_spec.dart';

part 'showcase_language_provider.g.dart';

/// Language of the passport content. The shell chrome itself stays English;
/// passports are bilingual for the Russian-speaking course and webinars.
@riverpod
class ShowcaseLanguageState extends _$ShowcaseLanguageState {
  @override
  ShowcaseLanguage build() => ShowcaseLanguage.en;

  void select(ShowcaseLanguage language) => state = language;
}
