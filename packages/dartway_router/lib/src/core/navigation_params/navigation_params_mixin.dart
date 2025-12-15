/// Mixin for type-safe navigation parameters
mixin NavigationParamsMixin<T> on Enum {
  /// Get parameter value from navigation parameters
  T? get(Map<String, String> navigationParameters) {
    final String? value = navigationParameters[name];

    if (value == null) {
      return null;
    }

    try {
      return _parseValue(value);
    } on FormatException catch (e) {
      throw FormatException(
        'Failed to parse parameter "$name" with value "$value" as ${T.toString()}: ${e.message}',
        value,
      );
    }
  }

  /// Get parameter value with default fallback
  T getOrDefault(Map<String, String> navigationParameters, T defaultValue) {
    try {
      return get(navigationParameters) ?? defaultValue;
    } on FormatException {
      return defaultValue;
    }
  }

  /// Set parameter value for navigation
  Map<String, String> set(T value) => {
        name: value.toString(),
      };

  T _parseValue(String value) {
    try {
      switch (T) {
        case const (int):
          return int.parse(value) as T;
        case const (double):
          return double.parse(value) as T;
        case const (bool):
          return (value.toLowerCase() == 'true') as T;
        case const (String):
          return value as T;
        default:
          return value as T;
      }
    } on FormatException catch (e) {
      throw FormatException(
        'Failed to parse "$value" as ${T.toString()}: ${e.message}',
        value,
      );
    }
  }
}
