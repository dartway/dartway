/// Route names across a Flutter app's navigation zones, read from source.
///
/// `DwAppRouter` resolves routes by name through one registry for the whole
/// app, and a name is the enum value's own `name` — so two zones declaring
/// `survey` collide. The router says so, but only when it is built: on the
/// first frame, as an error that takes the whole screen. The zones are enums
/// listed in source, so the collision is knowable before anything runs (#240).
library;

/// One zone's route: which enum declares it, and in which file.
typedef DwZoneRoute = ({String zone, String route, String file});

class DwRouteNames {
  const DwRouteNames._();

  static final _zoneHeader = RegExp(
    r'\benum\s+(\w+)\b[^{;]*\bimplements\b[^{;]*\bDwNavigationRoute\b[^{;]*\{',
  );

  static final _leadingName = RegExp(r'^[A-Za-z_$][\w$]*');

  /// Every route declared by a navigation-zone enum in [content].
  static List<DwZoneRoute> routesIn(String file, String content) {
    final code = _withoutCommentsAndStrings(content);
    return [
      for (final header in _zoneHeader.allMatches(code))
        for (final route in _valueNames(code, header.end))
          (zone: header.group(1)!, route: route, file: file),
    ];
  }

  /// Names declared by more than one zone value, each with its declarations.
  static Map<String, List<DwZoneRoute>> duplicates(
    Iterable<DwZoneRoute> routes,
  ) {
    final byName = <String, List<DwZoneRoute>>{};
    for (final route in routes) {
      (byName[route.route] ??= []).add(route);
    }
    return {
      for (final entry in byName.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
  }

  /// The value names of an enum body starting at [start]: items separated by
  /// commas at depth zero, up to the `;` or `}` that ends the value list.
  static List<String> _valueNames(String code, int start) {
    final names = <String>[];
    var depth = 0;
    var itemStart = start;
    void take(int end) {
      var item = code.substring(itemStart, end).trim();
      // Annotations on a value: `@Deprecated('…') survey(…)`.
      while (item.startsWith('@')) {
        item = item.replaceFirst(RegExp(r'^@[\w.]+\s*(\([^)]*\))?'), '').trim();
      }
      final name = _leadingName.firstMatch(item)?.group(0);
      if (name != null) names.add(name);
    }

    for (var i = start; i < code.length; i++) {
      final char = code[i];
      if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']') {
        depth--;
      } else if (char == '}') {
        if (depth == 0) {
          take(i);
          return names;
        }
        depth--;
      } else if (depth == 0 && (char == ',' || char == ';')) {
        take(i);
        if (char == ';') return names;
        itemStart = i + 1;
      }
    }
    return names;
  }

  /// [content] with comments removed and string contents blanked, so a
  /// bracket, comma or `//` inside either is not read as code.
  static String _withoutCommentsAndStrings(String content) {
    final out = StringBuffer();
    var i = 0;
    while (i < content.length) {
      if (content.startsWith('//', i)) {
        final end = content.indexOf('\n', i);
        i = end < 0 ? content.length : end;
        continue;
      }
      if (content.startsWith('/*', i)) {
        final end = content.indexOf('*/', i + 2);
        i = end < 0 ? content.length : end + 2;
        continue;
      }
      final char = content[i];
      if (char == "'" || char == '"') {
        final raw = i > 0 && content[i - 1] == 'r';
        final delimiter = content.startsWith(char * 3, i) ? char * 3 : char;
        var j = i + delimiter.length;
        while (j < content.length && !content.startsWith(delimiter, j)) {
          j += !raw && content[j] == r'\' ? 2 : 1;
        }
        out.write('""');
        i = j + delimiter.length;
        continue;
      }
      out.write(char);
      i++;
    }
    return out.toString();
  }
}
