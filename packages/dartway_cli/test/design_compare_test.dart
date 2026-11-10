import 'package:dartway_cli/src/design_check/design_compare.dart';
import 'package:dartway_cli/src/design_check/design_spec.dart';
import 'package:test/test.dart';

void main() {
  DesignNode node({
    List<double>? rect,
    String text = 'Save',
    String? fill = 'rgb(255, 255, 255)',
    String? stroke,
    double radius = 8,
    bool overflow = false,
    Map<String, Object?>? style,
  }) => DesignNode(
    path: 'button',
    rect: rect ?? [16, 20, 100, 40],
    text: text,
    fill: fill,
    stroke: stroke,
    radius: radius,
    overflow: overflow,
    textStyle: style ?? const {'fontSize': 16.0, 'fontWeight': '600'},
  );
  DesignSpec spec(DesignNode value, {double width = 375}) =>
      DesignSpec(viewport: [width, 812], nodes: [value]);

  test(
    'identical specs pass',
    () => expect(compareDesignSpecs(spec(node()), spec(node())), isEmpty),
  );

  test('meaningful geometry, text, style, and narrow overflow are found', () {
    final findings = compareDesignSpecs(
      spec(node()),
      spec(
        node(
          rect: [24, 20, 120, 40],
          text: 'Sa…',
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

  test(
    'sub-pixel styling, equivalent alpha colour, and small font metrics are noise',
    () {
      final reference = node(
        fill: 'rgb(255, 127, 127)',
        radius: 8,
        style: const {'fontSize': 16.0, 'lineHeight': 20.0},
      );
      final app = node(
        fill: 'rgba(255, 0, 0, 0.5)',
        radius: 8.8,
        style: const {'fontSize': 17.5, 'lineHeight': 22.0},
      );
      expect(compareDesignSpecs(spec(reference), spec(app)), isEmpty);
    },
  );
}
