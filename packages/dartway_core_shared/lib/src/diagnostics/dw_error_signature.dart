import 'dart:convert';

/// Selects the first stack frame owned by application code.
String dwFirstAppFrame(String stack) {
  for (final line in const LineSplitter().convert(stack)) {
    final frame = line.trim();
    if (frame.isEmpty ||
        frame.contains('<asynchronous suspension>') ||
        RegExp(r'(^|[\s(])dart:').hasMatch(frame) ||
        frame.contains('dart-sdk/') ||
        frame.contains('package:flutter/') ||
        _frameworkPackageFrame.hasMatch(frame)) {
      continue;
    }
    return frame.replaceFirst(RegExp(r'^#\d+\s+'), '');
  }
  return '';
}

final _frameworkPackageFrame = RegExp(
  r'package:dartway_(?:core_(?:shared|server|flutter)|client|orm|generator|router|shared_preferences|telegram|auth_[a-z_]+|analytics_[a-z_]+|push_[a-z_]+|media_flutter|studio_(?:bridge|binding)|lints|cli)/',
);
