// Feature code. Every style here is a style that escaped the kit, so every one
// of them must be reported: the annotation above each line makes the analyzer
// prove it — custom_lint fails when the promised lint does not appear, and
// equally when a lint appears that nobody promised.
//
// ignore_for_file: unused_local_variable, prefer_const_constructors

import 'package:flutter/material.dart';

import '../ui_kit/allowed_styles.dart';

class ForbiddenStyles extends StatelessWidget {
  const ForbiddenStyles({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: forbidden_ui_style_usage
    final color = Color(0xFF00FF00);

    // expect_lint: forbidden_ui_style_usage
    final style = TextStyle(fontSize: 12);

    // expect_lint: forbidden_ui_style_usage
    final radius = BorderRadius.circular(8);

    // expect_lint: forbidden_ui_style_usage
    final named = Colors.red;

    // The one the rule promised to catch and never did: `context.textTheme` is
    // a PrefixedIdentifier, and the rule was listening for PropertyAccess.
    // expect_lint: forbidden_ui_style_usage
    final text = context.textTheme;

    // expect_lint: forbidden_ui_style_usage
    final scheme = context.colorScheme;

    // expect_lint: forbidden_ui_style_usage
    final appTheme = context.theme;

    // expect_lint: forbidden_ui_style_usage
    final raw = Theme.of(context);

    return const SizedBox.shrink();
  }
}

class ForbiddenStylesInState extends StatefulWidget {
  const ForbiddenStylesInState({super.key});

  @override
  State<ForbiddenStylesInState> createState() => _ForbiddenStylesInStateState();
}

class _ForbiddenStylesInStateState extends State<ForbiddenStylesInState> {
  @override
  Widget build(BuildContext context) {
    // A State reaches its context through a property, so this one really is a
    // PropertyAccess — the node type the old rule listened for, and the only
    // shape it would have caught if anything ever wrote it this way.
    // expect_lint: forbidden_ui_style_usage
    final text = this.context.textTheme;

    // The type decides, not the spelling: a BuildContext named `ctx` is still a
    // BuildContext.
    final ctx = context;
    // expect_lint: forbidden_ui_style_usage
    final scheme = ctx.colorScheme;

    return Text('$text $scheme');
  }
}
