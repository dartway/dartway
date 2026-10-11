import 'dw_navigation_types.dart';

// One adapter for the deprecated String? contract and the decision contract.
DwGuardDecision resolveGuardDecision(Object? answer) => switch (answer) {
  DwGuardDecision decision => decision,
  String path => DwGuardDecision.redirect(path),
  null => DwGuardDecision.allow,
  _ => throw StateError('A navigation guard must return DwGuardDecision.'),
};
