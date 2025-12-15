import 'package:flutter/material.dart';

abstract class DwNotificationHandler<T> {
  void show(BuildContext context, T event);
}
