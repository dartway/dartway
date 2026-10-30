import 'dart:convert';

/// Selects the first stack frame owned by application code.
String dwFirstAppFrame(String stack) {
  for (final line in const LineSplitter().convert(stack)) {
    final frame = line.trim();
    if (frame.isEmpty ||
        frame.contains('<asynchronous suspension>') ||
        _dartFrame.hasMatch(frame) ||
        frame.contains('dart-sdk/') ||
        frame.contains('package:flutter/') ||
        _frameworkPackageFrame.hasMatch(frame)) {
      continue;
    }
    return _truncate(frame.replaceFirst(_framePrefix, ''), 512);
  }
  return '';
}

String dwNormalizeClientErrorLabel(String value) =>
    value.replaceAll(_controlCharacters, ' ');

final _dartFrame = RegExp(r'(^|[\s(])dart:');
final _framePrefix = RegExp(r'^#\d+\s+');
final _controlCharacters = RegExp(r'[\r\n\u0000-\u001f\u007f]');

String _truncate(String value, int bytes) {
  if (utf8.encode(value).length <= bytes) return value;
  final out = StringBuffer();
  var used = 0;
  for (final rune in value.runes) {
    final part = String.fromCharCode(rune);
    final size = utf8.encode(part).length;
    if (used + size > bytes) break;
    out.write(part);
    used += size;
  }
  return out.toString();
}

final _frameworkPackageFrame = RegExp(
  r'package:dartway_(?:core_(?:shared|server|flutter)|client|orm|generator|router|shared_preferences|telegram|auth_[a-z_]+|analytics_[a-z_]+|push_[a-z_]+|media_flutter|studio_(?:bridge|binding)|lints|cli)/',
);
