import 'package:flutter/material.dart';

/// A member's photo in a circle, or the placeholder icon while there is none.
///
/// A photo that does not load leaves the placeholder showing rather than an
/// error over the screen: a broken avatar is not worth interrupting anyone.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.avatarUrl,
    this.radius = 20,
    this.placeholder = Icons.person_outline,
    this.child,
    super.key,
  });

  final String? avatarUrl;
  final double radius;
  final IconData placeholder;

  /// Drawn over the circle instead of the placeholder icon — a progress
  /// indicator while a new photo uploads.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return CircleAvatar(
      radius: radius,
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError: url == null ? null : (_, _) {},
      // No placeholder under a photo: a transparent one would show it through.
      child:
          child ?? (url == null ? Icon(placeholder, size: radius * 0.8) : null),
    );
  }
}
