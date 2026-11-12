import 'package:dartway_cli/src/design_check/design_compare.dart';
import 'package:dartway_cli/src/design_check/design_spec.dart';
import 'package:test/test.dart';

void main() {
  DesignNode node({
    List<double>? rect,
    String text = 'Save',
    String? fill = 'rgb(255, 255, 255)',
    String? stroke,
    double? strokeWidth,
    String? shadow,
    String path = 'button',
    double radius = 8,
    bool overflow = false,
    bool truncated = false,
    Map<String, Object?>? style,
  }) => DesignNode(
    path: path,
    rect: rect ?? [16, 20, 100, 40],
    text: text,
    fill: fill,
    stroke: stroke,
    strokeWidth: strokeWidth,
    radius: radius,
    shadow: shadow,
    overflow: overflow,
    truncated: truncated,
    textStyle: style ?? const {'fontSize': 16.0, 'fontWeight': '600'},
  );

  DesignSpec spec(DesignNode value, {double width = 375}) =>
      DesignSpec(viewport: [width, 812], nodes: [value]);

  test('Chrome and Flutter encodings of the same text style pass', () {
    final reference = node(
      shadow: 'rgba(0, 0, 0, 0.25) 0px 2px 4px 0px',
      style: const {
        'fontFamily': 'Inter, Arial, sans-serif',
        'fontSize': 16.0,
        'color': 'rgb(0, 0, 0)',
      },
    );
    final app = node(
      shadow:
          'BoxShadow(Color(alpha: 0.2510, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB), Offset(0.0, 2.0), 4.0, 0.0, BlurStyle.normal)',
      style: const {
        'fontFamily': 'Inter',
        'fontSize': 16.0,
        'color': 'rgba(0, 0, 0, 1.000)',
      },
    );
    expect(compareDesignSpecs(spec(reference), spec(app)), isEmpty);
  });

  test('meaningfully different text colour, shadow, and font fail', () {
    final messages = compareDesignSpecs(
      spec(
        node(
          shadow: 'rgb(0, 0, 0) 0px 2px 4px 0px',
          style: const {'fontFamily': 'Inter', 'color': 'rgb(0, 0, 0)'},
        ),
      ),
      spec(
        node(
          shadow:
              'BoxShadow(Color(0xff000000), Offset(0.0, 8.0), 4.0, 0.0, BlurStyle.normal)',
          style: const {
            'fontFamily': 'Roboto',
            'color': 'rgba(255, 0, 0, 1.000)',
          },
        ),
      ),
    ).map((finding) => finding.message).join('\n');
    expect(messages, contains('Shadow differs'));
    expect(messages, contains('Text fontFamily'));
    expect(messages, contains('Text color'));
  });

  test('matching is independent of node order and path kinds', () {
    final save = node(text: 'Save', rect: [10, 10, 50, 20], path: 'button');
    final cancel = node(text: 'Cancel', rect: [100, 10, 60, 20], path: 'div');
    final actualCancel = node(
      text: 'Cancel',
      rect: [100, 10, 60, 20],
      path: 'Text#3',
    );
    final actualSave = node(
      text: 'Save',
      rect: [10, 10, 50, 20],
      path: 'Text#7',
    );
    expect(
      compareDesignSpecs(
        DesignSpec(viewport: [375, 812], nodes: [save, cancel]),
        DesignSpec(viewport: [375, 812], nodes: [actualCancel, actualSave]),
      ),
      isEmpty,
    );
  });

  test('identical specs pass', () {
    final nodes = [
      for (var index = 0; index < 40; index++)
        node(
          text: '',
          path: index.isEven ? 'div' : '#layer-$index',
          rect: [0, 0, 400.0 - index, 800.0 - index],
        ),
    ];
    final reference = DesignSpec(viewport: [400, 800], nodes: nodes);
    final app = DesignSpec(
      viewport: [400, 800],
      nodes: [
        for (var index = 0; index < nodes.length; index++)
          node(
            text: '',
            path: 'RenderDecoratedBox#$index',
            rect: List.of(nodes[index].rect),
          ),
      ],
    );
    expect(compareDesignSpecs(reference, app), isEmpty);
  });

  test('meaningful geometry, text, style, and narrow overflow are found', () {
    final findings = compareDesignSpecs(
      spec(node()),
      spec(
        node(
          rect: [24, 20, 120, 40],
          truncated: true,
          fill: 'rgb(0, 0, 0)',
          radius: 14,
          overflow: true,
          style: const {'fontSize': 22.0, 'fontWeight': '400'},
        ),
      ),
    ).map((finding) => finding.message).join('\n');
    expect(findings, contains('left is 24 instead of 16'));
    expect(findings, contains('truncated with an ellipsis'));
    expect(findings, contains('Fill is'));
    expect(findings, contains('Corner radius'));
    expect(findings, contains('overflows the 375 px viewport'));
    expect(findings, contains('Text fontSize'));
  });

  test('sub-pixel styling and small line-height differences are noise', () {
    final reference = node(
      fill: 'rgb(255, 127, 127)',
      radius: 8,
      style: const {'fontSize': 16.0, 'lineHeight': 20.0},
    );
    final app = node(
      fill: 'rgba(255, 0, 0, 0.5)',
      radius: 8.8,
      style: const {'fontSize': 16.4, 'lineHeight': 22.0},
    );
    expect(compareDesignSpecs(spec(reference), spec(app)), isEmpty);
  });

  test('meaningful font-size changes are reported', () {
    final findings = compareDesignSpecs(
      spec(node(style: const {'fontSize': 16.0})),
      spec(node(style: const {'fontSize': 17.5})),
    );
    expect(
      findings.map((finding) => finding.message),
      contains('Text fontSize is 17.5 instead of 16.0.'),
    );
  });

  test('translucent colours are compared on their painted backdrop', () {
    DesignSpec layered(String foreground) => DesignSpec(
      viewport: [375, 812],
      nodes: [
        node(
          path: 'body',
          rect: [0, 0, 375, 812],
          fill: 'rgb(0, 0, 0)',
          text: '',
        ),
        node(path: 'card', fill: foreground),
      ],
    );
    expect(
      compareDesignSpecs(
        layered('rgba(255, 255, 255, 0.5)'),
        layered('rgb(128, 128, 128)'),
      ),
      isEmpty,
    );
    expect(
      compareDesignSpecs(
        layered('rgba(255, 255, 255, 0.5)'),
        layered('rgb(255, 255, 255)'),
      ),
      isNotEmpty,
    );
  });

  test('viewport and meaningful stroke width differences are found', () {
    final findings = compareDesignSpecs(
      spec(node(stroke: 'rgb(0, 0, 0)', strokeWidth: 1)),
      spec(node(stroke: 'rgba(0, 0, 0, 1)', strokeWidth: 3), width: 400),
    ).map((finding) => finding.message).join('\n');
    expect(findings, contains('App viewport is 400x812 instead of 375x812'));
    expect(findings, contains('Stroke width is 3 instead of 1'));
  });

  test('matching design overflow and truncation are not app findings', () {
    expect(
      compareDesignSpecs(
        spec(node(text: 'Design label', overflow: true, truncated: true)),
        spec(node(text: 'App label', overflow: true, truncated: true)),
      ).map((finding) => finding.message),
      contains('Text is "App label" instead of "Design label".'),
    );
    expect(
      compareDesignSpecs(
        spec(node(overflow: true, truncated: true)),
        spec(node(overflow: true, truncated: true)),
      ),
      isEmpty,
    );
  });

  test('absent values have the same encoding on both capture sides', () {
    expect(
      compareDesignSpecs(
        spec(
          node(
            text: '',
            fill: 'rgba(0, 0, 0, 0)',
            style: const {'color': 'rgba(0, 0, 0, 0)'},
          ),
        ),
        spec(node(text: '', fill: null, style: const {'color': null})),
      ),
      isEmpty,
    );
  });
}
