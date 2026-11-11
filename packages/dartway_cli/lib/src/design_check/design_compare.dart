import 'dart:math' as math;

import 'design_spec.dart';

class DesignFinding {
  const DesignFinding(this.node, this.message);
  final String node;
  final String message;
  Map<String, String> toJson() => {'node': node, 'message': message};
}

/// Compares two captured static trees. Geometry within two logical pixels,
/// strokes within one pixel and equivalent alpha-composited colours are noise.
List<DesignFinding> compareDesignSpecs(DesignSpec reference, DesignSpec app) {
  final findings = <DesignFinding>[];
  final matches = _matchNodes(reference.nodes, app.nodes);
  for (final expected in reference.nodes) {
    final candidate = matches[expected];
    if (candidate == null) {
      findings.add(DesignFinding(expected.path, 'Visible node is missing.'));
      continue;
    }
    final labels = ['left', 'top', 'width', 'height'];
    for (var index = 0; index < 4; index++) {
      final difference = candidate.rect[index] - expected.rect[index];
      if (difference.abs() > 2) {
        findings.add(
          DesignFinding(
            expected.path,
            '${labels[index]} is ${_number(candidate.rect[index])} instead of '
            '${_number(expected.rect[index])} (${difference > 0 ? '+' : ''}${_number(difference)} px).',
          ),
        );
      }
    }
    if ((candidate.radius ?? 0) - (expected.radius ?? 0) case final delta
        when delta.abs() > 1) {
      findings.add(
        DesignFinding(
          expected.path,
          'Corner radius is ${_number(candidate.radius ?? 0)} instead of ${_number(expected.radius ?? 0)}.',
        ),
      );
    }
    if (!_sameColour(expected.fill, candidate.fill)) {
      findings.add(
        DesignFinding(
          expected.path,
          'Fill is ${candidate.fill ?? 'none'} instead of ${expected.fill ?? 'none'}.',
        ),
      );
    }
    if (!_sameColour(expected.stroke, candidate.stroke)) {
      findings.add(
        DesignFinding(
          expected.path,
          'Stroke is ${candidate.stroke ?? 'none'} instead of ${expected.stroke ?? 'none'}.',
        ),
      );
    }
    if (!_sameShadow(expected.shadow, candidate.shadow)) {
      findings.add(
        DesignFinding(expected.path, 'Shadow differs from the design.'),
      );
    }
    for (final key in {
      ...expected.textStyle.keys,
      ...candidate.textStyle.keys,
    }) {
      final a = expected.textStyle[key];
      final b = candidate.textStyle[key];
      final metric = key == 'fontSize' || key == 'lineHeight';
      if (metric && a is num && b is num && (a - b).abs() <= 2) continue;
      final same = key == 'color'
          ? _sameColour(a as String?, b as String?)
          : key == 'fontFamily'
          ? _sameFontFamily(a as String?, b as String?)
          : a == b;
      if (!same)
        findings.add(
          DesignFinding(expected.path, 'Text $key is $b instead of $a.'),
        );
    }
    if (candidate.overflow) {
      findings.add(
        DesignFinding(
          expected.path,
          'Fixed size overflows the ${_number(app.viewport.first)} px viewport.',
        ),
      );
    }
    if (candidate.text != expected.text) {
      final ellipsis = candidate.text?.endsWith('…') ?? false;
      findings.add(
        DesignFinding(
          expected.path,
          ellipsis
              ? 'Text is truncated with an ellipsis: "${candidate.text}".'
              : 'Text is "${candidate.text ?? ''}" instead of "${expected.text ?? ''}".',
        ),
      );
    }
  }
  for (final node in app.nodes.where((node) => !matches.containsValue(node))) {
    findings.add(DesignFinding(node.path, 'Unexpected visible node.'));
  }
  return findings;
}

Map<DesignNode, DesignNode> _matchNodes(
  List<DesignNode> reference,
  List<DesignNode> app,
) {
  final edges = <(DesignNode, DesignNode)>[
    for (final expected in reference)
      for (final actual in app) (expected, actual),
  ]..sort((a, b) => _matchScore(a.$1, a.$2).compareTo(_matchScore(b.$1, b.$2)));
  final result = <DesignNode, DesignNode>{};
  final used = <DesignNode>{};
  for (final edge in edges) {
    if (result.containsKey(edge.$1) || used.contains(edge.$2)) continue;
    result[edge.$1] = edge.$2;
    used.add(edge.$2);
  }
  return result;
}

double _matchScore(DesignNode a, DesignNode b) {
  final bothHaveText =
      (a.text?.isNotEmpty ?? false) || (b.text?.isNotEmpty ?? false);
  final textPenalty = bothHaveText && a.text != b.text ? 1000000.0 : 0.0;
  final rolePenalty = _role(a.path) == _role(b.path) ? 0.0 : 1000.0;
  return textPenalty + rolePenalty + _distance(a, b);
}

String _role(String path) =>
    path.split('/').last.split('#').first.toLowerCase();

double _distance(DesignNode a, DesignNode b) => math.sqrt(
  math.pow(a.rect[0] - b.rect[0], 2) + math.pow(a.rect[1] - b.rect[1], 2),
);

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

bool _sameColour(String? a, String? b) {
  if (a == b) return true;
  final first = _rgba(a);
  final second = _rgba(b);
  if (first == null || second == null) return false;
  // Treat a translucent colour as its equivalent solid rendering on white.
  List<int> flatten(List<int> value) => [
    for (var i = 0; i < 3; i++)
      (value[i] * value[3] / 255 + 255 - value[3]).round(),
  ];
  final x = flatten(first), y = flatten(second);
  return List.generate(
    3,
    (i) => (x[i] - y[i]).abs(),
  ).every((difference) => difference <= 1);
}

List<int>? _rgba(String? colour) {
  if (colour == null) return null;
  final match = RegExp(
    r'^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)$',
  ).firstMatch(colour);
  if (match == null) return null;
  return [
    for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
    (double.parse(match.group(4) ?? '1') * 255).round(),
  ];
}

bool _sameFontFamily(String? a, String? b) {
  if (a == b) return true;
  Set<String> families(String? value) => value == null
      ? const {}
      : value
            .split(',')
            .map(
              (part) => part
                  .trim()
                  .replaceAll(RegExp(r'''^['"]|['"]$'''), '')
                  .toLowerCase(),
            )
            .where((part) => part.isNotEmpty)
            .toSet();
  return families(a).intersection(families(b)).isNotEmpty;
}

bool _sameShadow(String? a, String? b) {
  if (a == b) return true;
  final first = _shadow(a), second = _shadow(b);
  if (first == null || second == null) return false;
  return _sameColour(first.$1, second.$1) &&
      List.generate(
        4,
        (i) => (first.$2[i] - second.$2[i]).abs(),
      ).every((difference) => difference <= 1);
}

(String, List<double>)? _shadow(String? value) {
  if (value == null || value == 'none') return null;
  final css = RegExp(
    r'^(rgba?\([^)]+\))\s+(-?[\d.]+)px\s+(-?[\d.]+)px\s+([\d.]+)px(?:\s+(-?[\d.]+)px)?$',
  ).firstMatch(value.trim());
  if (css != null) {
    return (
      css.group(1)!,
      [for (var i = 2; i <= 5; i++) double.parse(css.group(i) ?? '0')],
    );
  }
  final flutter = RegExp(
    r'BoxShadow\(Color\(0x([0-9a-fA-F]{8})\), Offset\((-?[\d.]+), (-?[\d.]+)\), ([\d.]+), (-?[\d.]+)',
  ).firstMatch(value.trim());
  if (flutter != null) {
    final hex = flutter.group(1)!;
    final alpha = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final colour =
        'rgba(${int.parse(hex.substring(2, 4), radix: 16)}, '
        '${int.parse(hex.substring(4, 6), radix: 16)}, '
        '${int.parse(hex.substring(6, 8), radix: 16)}, $alpha)';
    return (
      colour,
      [for (var i = 2; i <= 5; i++) double.parse(flutter.group(i)!)],
    );
  }
  final components = RegExp(
    r'BoxShadow\(Color\(alpha: ([\d.]+), red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+),[^)]*\), Offset\((-?[\d.]+), (-?[\d.]+)\), ([\d.]+), (-?[\d.]+)',
  ).firstMatch(value.trim());
  if (components == null) return null;
  final colour =
      'rgba(${(double.parse(components.group(2)!) * 255).round()}, '
      '${(double.parse(components.group(3)!) * 255).round()}, '
      '${(double.parse(components.group(4)!) * 255).round()}, '
      '${components.group(1)})';
  return (
    colour,
    [for (var i = 5; i <= 8; i++) double.parse(components.group(i)!)],
  );
}
