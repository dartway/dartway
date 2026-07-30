import 'package:yaml/yaml.dart';

/// Typed access to a YAML map with error messages that name the file and key.
///
/// Deployment configuration is edited by hand, so a wrong key must produce a
/// message that says where to look rather than a cast exception.
class DwYamlReader {
  DwYamlReader(this.map, {required this.source});

  final YamlMap map;

  /// Human-readable origin used in error messages, e.g. `deploy/config.yaml`.
  final String source;

  String requiredString(String key) {
    final value = optionalString(key);
    if (value == null) {
      throw StateError('$source: missing required key "$key".');
    }
    return value;
  }

  String? optionalString(String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int? optionalInt(String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      throw StateError('$source: "$key" must be an integer, got "$value".');
    }
    return parsed;
  }

  bool? optionalBool(String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    switch (value.toString().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
    throw StateError('$source: "$key" must be true or false, got "$value".');
  }

  YamlMap? optionalMap(String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is! YamlMap) {
      throw StateError('$source: "$key" must be a map.');
    }
    return value;
  }

  List<String> optionalStringList(String key) {
    final value = map[key];
    if (value == null) {
      return const [];
    }
    if (value is! YamlList) {
      throw StateError('$source: "$key" must be a list.');
    }
    return value.map((item) => item.toString().trim()).toList();
  }

  List<int> optionalIntList(String key) {
    final value = map[key];
    if (value == null) {
      return const [];
    }
    if (value is! YamlList) {
      throw StateError('$source: "$key" must be a list.');
    }
    return value.map((item) {
      if (item is int) {
        return item;
      }
      final parsed = int.tryParse(item.toString());
      if (parsed == null) {
        throw StateError('$source: "$key" must contain integers.');
      }
      return parsed;
    }).toList();
  }
}
