import 'package:flutter/material.dart';

typedef DwPageBuilder = Page<dynamic> Function(
  BuildContext context,
  LocalKey key,
  Widget child,
);
