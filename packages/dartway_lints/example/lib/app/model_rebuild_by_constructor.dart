// Application code rebuilding a stored model. The trap is that none of these
// calls is wrong today: they compile, they pass review, and they keep compiling
// on the day a field is added to the model — at which point the field silently
// arrives as its default in every one of them.

import '../src/protocol/club_session.dart';

class SessionEditor {
  /// The original bug, in miniature: a method that rebuilds the model by naming
  /// its fields. Add `priority` to `ClubSession` and this call resets it.
  ClubSession publish(ClubSession session) {
    // expect_lint: model_rebuild_by_constructor
    return ClubSession(
      id: session.id,
      title: session.title,
      description: session.description,
      isPublished: true,
    );
  }

  /// The same shape with a literal id — a rebuild all the same, and the rule
  /// looks at the argument being there rather than at where its value came from.
  ClubSession rename(String title) {
    // expect_lint: model_rebuild_by_constructor
    return ClubSession(id: 42, title: title);
  }

  /// The replacement. Nothing is lost by it: `description: null` clears the
  /// field, because the generated `copyWith` tells "passed null" apart from
  /// "not passed".
  ClubSession publishProperly(ClubSession session) =>
      session.copyWith(isPublished: true, description: null);

  /// Creating a row: no id, because the id comes back from the database.
  ClubSession createDraft(String title) => ClubSession(title: title);

  /// The same, with the absence spelled out. A field-by-field call that says
  /// `id: null` is not rebuilding anything.
  ClubSession createExplicitDraft(String title) =>
      ClubSession(id: null, title: title);
}

/// `id:` is a common argument name, and on anything that is not a Serverpod
/// model it means nothing to this rule. The shape below is everywhere in a
/// DartWay app — every feature declares its spec with a string id — and it must
/// stay silent.
class FeatureSpec {
  const FeatureSpec({required this.id, required this.summary});

  final String id;
  final String summary;
}

const scheduleFeature = FeatureSpec(
  id: 'schedule/page',
  summary: 'The club schedule for the week',
);
