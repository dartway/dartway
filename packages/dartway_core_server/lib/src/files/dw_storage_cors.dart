import 'dart:convert';

/// Internal CORS policy used by server provisioning. The CLI satellite owns
/// a matching constant, verified by its contract test.
/// Not exported from the server public library.
final class DwStorageCorsRule {
  DwStorageCorsRule(Iterable<String> origins)
    : _rule = {
        'AllowedOrigins': origins.toList(),
        'AllowedMethods': ['GET', 'PUT'],
        'AllowedHeaders': ['*'],
        'MaxAgeSeconds': 3000,
      };

  final Map<String, Object> _rule;

  String get json => jsonEncode({
    'CORSRules': [_rule],
  });

  String get xml {
    const escape = HtmlEscape(HtmlEscapeMode.element);
    final body = StringBuffer();
    for (final entry in _rule.entries) {
      final values = entry.value is List ? entry.value as List : [entry.value];
      final tag = entry.value is List
          ? entry.key.substring(0, entry.key.length - 1)
          : entry.key;
      for (final value in values) {
        body.write('<$tag>${escape.convert('$value')}</$tag>');
      }
    }
    return '<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
        '<CORSRule>$body</CORSRule></CORSConfiguration>';
  }
}
