// A feature reaching in three directions at once. Only the far ones may be
// reported: the rule is about distance, and a rule that also flagged the
// neighbour would push every project to `package:` everywhere — which is the
// blunt lint we deliberately did not enable.
//
// ignore_for_file: unused_import, depend_on_referenced_packages

// The feature's own internals — no steps up at all.
import 'widgets/feature_a_body.dart';

// A sibling feature in the same group — one step up, the shape the rule exists
// to keep legal.
import '../feature_b/feature_b.dart';

// expect_lint: deep_relative_import
import '../../../ui_kit/allowed_styles.dart';

class FeatureA {}
