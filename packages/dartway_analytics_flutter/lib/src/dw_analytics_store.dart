import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the analytics plugin keeps on the device between runs: the install
/// id, the next sequence number, and the events not yet confirmed by the
/// server.
abstract interface class DwAnalyticsStore {
  Future<String?> readInstallId();
  Future<void> writeInstallId(String installId);
  Future<int> readNextSequence();
  Future<void> writeNextSequence(int next);
  Future<List<Map<String, Object?>>> readQueue();
  Future<void> writeQueue(List<Map<String, Object?>> queue);
}

/// The store on the device's shared preferences.
final class DwPreferencesAnalyticsStore implements DwAnalyticsStore {
  DwPreferencesAnalyticsStore({this.prefix = 'dw.analytics.'});

  final String prefix;
  SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  @override
  Future<String?> readInstallId() => _prefs.getString('${prefix}installId');

  @override
  Future<void> writeInstallId(String installId) =>
      _prefs.setString('${prefix}installId', installId);

  @override
  Future<int> readNextSequence() async =>
      await _prefs.getInt('${prefix}nextSequence') ?? 1;

  @override
  Future<void> writeNextSequence(int next) =>
      _prefs.setInt('${prefix}nextSequence', next);

  @override
  Future<List<Map<String, Object?>>> readQueue() async {
    final raw = await _prefs.getString('${prefix}queue');
    if (raw == null) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          (item as Map).cast<String, Object?>(),
      ];
    } on FormatException {
      return [];
    }
  }

  @override
  Future<void> writeQueue(List<Map<String, Object?>> queue) =>
      _prefs.setString('${prefix}queue', jsonEncode(queue));
}

/// A store in memory, for tests.
final class DwMemoryAnalyticsStore implements DwAnalyticsStore {
  String? installId;
  int nextSequence = 1;
  List<Map<String, Object?>> queue = [];

  @override
  Future<String?> readInstallId() async => installId;

  @override
  Future<void> writeInstallId(String value) async => installId = value;

  @override
  Future<int> readNextSequence() async => nextSequence;

  @override
  Future<void> writeNextSequence(int next) async => nextSequence = next;

  @override
  Future<List<Map<String, Object?>>> readQueue() async => [
    for (final item in queue) Map.of(item),
  ];

  @override
  Future<void> writeQueue(List<Map<String, Object?>> value) async =>
      queue = [for (final item in value) Map.of(item)];
}
