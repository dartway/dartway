// The kit is where styles are allowed to be written — that is the whole point
// of the rule. Not a single lint may fire in this file: `custom_lint` reports
// any lint that no `expect_lint` asked for, so an over-eager rule fails here.
//
// ignore_for_file: unused_local_variable, prefer_const_constructors

import 'package:flutter/material.dart';

extension AppBuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

enum AppTextStyle {
  title,
  body;

  TextStyle resolve(BuildContext context) => switch (this) {
    AppTextStyle.title => context.textTheme.titleLarge ?? TextStyle(),
    AppTextStyle.body => context.textTheme.bodyMedium ?? TextStyle(),
  };
}

class AppCard extends StatelessWidget {
  const AppCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}
