import 'dart:convert';

class DesignNode {
  const DesignNode({
    required this.path,
    required this.rect,
    this.text,
    this.fill,
    this.stroke,
    this.radius,
    this.shadow,
    this.textStyle = const {},
    this.overflow = false,
  });

  factory DesignNode.fromJson(Map<String, Object?> json) => DesignNode(
    path: json['path']! as String,
    rect: (json['rect']! as List)
        .map((value) => (value as num).toDouble())
        .toList(),
    text: json['text'] as String?,
    fill: json['fill'] as String?,
    stroke: json['stroke'] as String?,
    radius: (json['radius'] as num?)?.toDouble(),
    shadow: json['shadow'] as String?,
    textStyle: (json['textStyle'] as Map?)?.cast<String, Object?>() ?? const {},
    overflow: json['overflow'] as bool? ?? false,
  );

  final String path;
  final List<double> rect;
  final String? text;
  final String? fill;
  final String? stroke;
  final double? radius;
  final String? shadow;
  final Map<String, Object?> textStyle;
  final bool overflow;
}

class DesignSpec {
  const DesignSpec({required this.viewport, required this.nodes});

  factory DesignSpec.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    return DesignSpec(
      viewport: (json['viewport']! as List)
          .map((value) => (value as num).toDouble())
          .toList(),
      nodes: (json['nodes']! as List)
          .map(
            (value) =>
                DesignNode.fromJson((value as Map).cast<String, Object?>()),
          )
          .toList(),
    );
  }

  final List<double> viewport;
  final List<DesignNode> nodes;
}
