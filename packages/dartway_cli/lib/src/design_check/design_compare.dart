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
  final unused = app.nodes.toList();
  for (final expected in reference.nodes) {
    final candidate = _takeMatch(expected, unused);
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
    if (expected.shadow != candidate.shadow) {
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
      if (a != b)
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
  for (final node in unused) {
    findings.add(DesignFinding(node.path, 'Unexpected visible node.'));
  }
  return findings;
}

DesignNode? _takeMatch(DesignNode node, List<DesignNode> candidates) {
  if (candidates.isEmpty) return null;
  var best = candidates.where((item) => item.text == node.text).toList();
  if (best.isEmpty)
    best = candidates
        .where((item) => item.path.split('/').last == node.path.split('/').last)
        .toList();
  if (best.isEmpty) best = candidates.toList();
  best.sort((a, b) => _distance(node, a).compareTo(_distance(node, b)));
  return candidates.removeAt(candidates.indexOf(best.first));
}

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
