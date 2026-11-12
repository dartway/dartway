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
  if ((reference.viewport[0] - app.viewport[0]).abs() > .5 ||
      (reference.viewport[1] - app.viewport[1]).abs() > .5) {
    findings.add(
      DesignFinding(
        'viewport',
        'App viewport is ${_number(app.viewport[0])}x${_number(app.viewport[1])} '
            'instead of ${_number(reference.viewport[0])}x${_number(reference.viewport[1])}.',
      ),
    );
  }
  final matches = _matchNodes(reference.nodes, app.nodes);
  for (final expected in reference.nodes) {
    final candidate = matches[expected];
    if (candidate == null) {
      findings.add(DesignFinding(expected.path, 'Visible node is missing.'));
      continue;
    }
    final expectedParent = _parentOf(expected, reference.nodes);
    final candidateParent = expectedParent == null
        ? null
        : matches[expectedParent];
    final labels = ['left', 'top', 'width', 'height'];
    for (var index = 0; index < 4; index++) {
      final expectedValue = index < 2 && expectedParent != null
          ? expected.rect[index] - expectedParent.rect[index]
          : expected.rect[index];
      final candidateValue = index < 2 && candidateParent != null
          ? candidate.rect[index] - candidateParent.rect[index]
          : candidate.rect[index];
      final difference = candidateValue - expectedValue;
      if (difference.abs() > 2) {
        final label = index < 2 && expectedParent != null
            ? 'Padding ${index == 0 ? 'left' : 'top'}'
            : labels[index];
        findings.add(
          DesignFinding(
            expected.path,
            '$label is ${_number(candidateValue)} instead of '
            '${_number(expectedValue)} (${difference > 0 ? '+' : ''}${_number(difference)} px).',
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
    if (!_sameColour(
      expected.fill,
      candidate.fill,
      _backdrop(expected, reference.nodes),
      _backdrop(candidate, app.nodes),
    )) {
      findings.add(
        DesignFinding(
          expected.path,
          'Fill is ${candidate.fill ?? 'none'} instead of ${expected.fill ?? 'none'}.',
        ),
      );
    }
    if (!_sameColour(
      expected.stroke,
      candidate.stroke,
      _backdrop(expected, reference.nodes),
      _backdrop(candidate, app.nodes),
    )) {
      findings.add(
        DesignFinding(
          expected.path,
          'Stroke is ${candidate.stroke ?? 'none'} instead of ${expected.stroke ?? 'none'}.',
        ),
      );
    }
    final strokeDelta =
        (candidate.strokeWidth ?? 0) - (expected.strokeWidth ?? 0);
    if (strokeDelta.abs() > 1) {
      findings.add(
        DesignFinding(
          expected.path,
          'Stroke width is ${_number(candidate.strokeWidth ?? 0)} instead of '
          '${_number(expected.strokeWidth ?? 0)}.',
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
      if (a == null && b == null) continue;
      final metric = key == 'lineHeight';
      if (metric && a is num && b is num && (a - b).abs() <= 2) continue;
      if (key == 'fontSize' && a is num && b is num && (a - b).abs() <= .5) {
        continue;
      }
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
    if (candidate.overflow && !expected.overflow) {
      findings.add(
        DesignFinding(
          expected.path,
          'Fixed size overflows the ${_number(app.viewport.first)} px viewport.',
        ),
      );
    }
    if (candidate.truncated != expected.truncated) {
      findings.add(
        DesignFinding(
          expected.path,
          candidate.truncated
              ? 'Text is truncated with an ellipsis in the app but not in the design.'
              : 'Text is truncated with an ellipsis in the design but not in the app.',
        ),
      );
    }
    if (_text(candidate.text) != _text(expected.text)) {
      findings.add(
        DesignFinding(
          expected.path,
          'Text is "${candidate.text ?? ''}" instead of "${expected.text ?? ''}".',
        ),
      );
    }
  }
  for (final node in app.nodes.where((node) => !matches.containsValue(node))) {
    findings.add(DesignFinding(node.path, 'Unexpected visible node.'));
  }
  return findings;
}

String? _text(String? value) => value == null || value.isEmpty ? null : value;

Map<DesignNode, DesignNode> _matchNodes(
  List<DesignNode> reference,
  List<DesignNode> app,
) {
  final edges =
      <(DesignNode, DesignNode, int, int)>[
        for (
          var expectedIndex = 0;
          expectedIndex < reference.length;
          expectedIndex++
        )
          for (var actualIndex = 0; actualIndex < app.length; actualIndex++)
            (
              reference[expectedIndex],
              app[actualIndex],
              expectedIndex,
              actualIndex,
            ),
      ]..sort((a, b) {
        final score = _matchScore(
          a.$1,
          a.$2,
        ).compareTo(_matchScore(b.$1, b.$2));
        if (score != 0) return score;
        final expected = a.$3.compareTo(b.$3);
        return expected != 0 ? expected : a.$4.compareTo(b.$4);
      });
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
  return textPenalty + rolePenalty + _distance(a, b) + _sizeDistance(a, b);
}

String _role(String path) {
  final role = path.split('/').last.split('#').first.toLowerCase();
  if (role == 'image' ||
      role == 'img' ||
      role == 'svg' ||
      role == 'renderimage') {
    return 'image';
  }
  if (role.endsWith('-text') || role == 'p' || role == 'renderparagraph') {
    return 'text';
  }
  return 'box';
}

double _distance(DesignNode a, DesignNode b) => math.sqrt(
  math.pow(a.rect[0] - b.rect[0], 2) + math.pow(a.rect[1] - b.rect[1], 2),
);

double _sizeDistance(DesignNode a, DesignNode b) => math.sqrt(
  math.pow(a.rect[2] - b.rect[2], 2) + math.pow(a.rect[3] - b.rect[3], 2),
);

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

bool _sameColour(String? a, String? b, [String? backdropA, String? backdropB]) {
  if (_transparent(a) && _transparent(b)) return true;
  if (a == b) return true;
  final first = _rgba(a);
  final second = _rgba(b);
  if (first == null || second == null) return false;
  List<int> flatten(List<int> value, String? backdrop) {
    final behind = _rgba(backdrop) ?? const [255, 255, 255, 255];
    return [
      for (var i = 0; i < 3; i++)
        (value[i] * value[3] / 255 + behind[i] * (255 - value[3]) / 255)
            .round(),
    ];
  }

  final x = flatten(first, backdropA), y = flatten(second, backdropB);
  return List.generate(
    3,
    (i) => (x[i] - y[i]).abs(),
  ).every((difference) => difference <= 1);
}

DesignNode? _parentOf(DesignNode node, List<DesignNode> nodes) {
  final containers = nodes
      .where(
        (other) =>
            !identical(other, node) &&
            other.rect[0] <= node.rect[0] &&
            other.rect[1] <= node.rect[1] &&
            other.rect[0] + other.rect[2] >= node.rect[0] + node.rect[2] &&
            other.rect[1] + other.rect[3] >= node.rect[1] + node.rect[3],
      )
      .toList();
  containers.sort(
    (a, b) => (a.rect[2] * a.rect[3]).compareTo(b.rect[2] * b.rect[3]),
  );
  return containers.firstOrNull;
}

String? _backdrop(DesignNode node, List<DesignNode> nodes) {
  var parent = _parentOf(node, nodes);
  while (parent != null) {
    if (!_transparent(parent.fill)) return parent.fill;
    parent = _parentOf(parent, nodes);
  }
  return null;
}

bool _transparent(String? value) {
  if (value == null || value == 'transparent') return true;
  final rgba = _rgba(value);
  return rgba != null && rgba[3] == 0;
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
