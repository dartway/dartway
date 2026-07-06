import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_example_flutter/core/router/router.dart';

enum ShowcaseLanguage { en, ru }

/// A bilingual text snippet: passports serve both the public repo (EN) and
/// the Russian-speaking course/webinars (RU).
class ShowcaseText {
  const ShowcaseText(this.en, this.ru);

  final String en;
  final String ru;

  String resolve(ShowcaseLanguage language) =>
      language == ShowcaseLanguage.ru ? ru : en;
}

/// The screen passport: single source of truth reused by the showcase panel,
/// the course track and the docs.
class ShowcaseScreenSpec {
  const ShowcaseScreenSpec({
    required this.route,
    required this.title,
    required this.purpose,
    required this.featureSpec,
    required this.discussionQuestions,
  });

  final DwNavigationRoute<AppRouterState> route;
  final ShowcaseText title;

  /// CJM / business context: why this screen exists.
  final ShowcaseText purpose;

  /// Which DartWay capability each feature of the screen demonstrates.
  final List<ShowcaseText> featureSpec;

  final List<ShowcaseText> discussionQuestions;
}

/// Navigation zones have no display metadata in the router — labels and the
/// screen order live here.
class ShowcaseZoneSpec {
  const ShowcaseZoneSpec({
    required this.label,
    required this.rootRoute,
    required this.screens,
  });

  final ShowcaseText label;
  final DwNavigationRoute<AppRouterState> rootRoute;
  final List<ShowcaseScreenSpec> screens;
}
