import 'dart:convert';
import 'dart:io';

/// Where a deployment reports what it does: prose for a person, and — when a
/// program started it — one JSON object per line for that program.
///
/// In JSON mode stdout carries the events and nothing else, and the prose goes
/// to stderr, so a caller parses the one stream and logs the other. The events
/// are the contract; the prose may change wording at any time.
class DwDeployProgress {
  DwDeployProgress.text() : human = stdout, _events = null;

  DwDeployProgress.json() : human = stderr, _events = stdout;

  /// A progress that writes prose to [human] and events to [events].
  DwDeployProgress.into({required this.human, IOSink? events})
    : _events = events;

  /// The sink for people: stdout in text mode, stderr in JSON mode.
  final IOSink human;
  final IOSink? _events;

  /// The sink for failures a person must read.
  IOSink get problems => _events == null ? stderr : human;

  bool get emitsEvents => _events != null;

  /// Writes one event, `{"event": name, ...fields}`, when events are on.
  void event(String name, [Map<String, Object?> fields = const {}]) {
    _events?.writeln(jsonEncode({'event': name, ...fields}));
  }
}
