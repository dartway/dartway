part of '../../ui_kit.dart';

/// Slices of a whole, with a legend: each value's colour, label, number and
/// share. [rest] — "other" — is the last slice, in the rest colour.
///
/// The ring is painted: a pie is arcs, which no layout widget draws. The
/// colours come from the theme ([AppChartColors]), resolved in `build`.
class AppPieChart extends StatelessWidget {
  const AppPieChart({
    super.key,
    required this.values,
    this.rest,
    this.size = 120,
  });

  final List<AppChartValue> values;
  final AppChartValue? rest;
  final double size;

  @override
  Widget build(BuildContext context) {
    final slices = [
      for (final (index, value) in values.indexed)
        (value: value, color: context.chartColor(index)),
      if (rest case final rest?) (value: rest, color: context.chartRestColor),
    ];
    final total = slices.fold<num>(0, (sum, s) => sum + s.value.value);
    final percent = NumberFormat.percentPattern();
    final number = NumberFormat.decimalPattern();

    final ring = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PiePainter([
          for (final s in slices) (s.value.value.toDouble(), s.color),
        ], track: context.colorScheme.surfaceContainer),
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText.body(
                    slice.value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                AppText.caption(
                  '${number.format(slice.value.value)} · '
                  '${percent.format(total <= 0 ? 0 : slice.value.value / total)}',
                ),
              ],
            ),
          ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ring,
        const SizedBox(width: 16),
        Expanded(child: legend),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, {required this.track});

  final List<(double, Color)> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.22;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = slices.fold<double>(0, (sum, s) => sum + s.$1);
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * pi, false, paint..color = track);
      return;
    }
    var start = -pi / 2;
    for (final (value, color) in slices) {
      final sweep = value / total * 2 * pi;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.track != track ||
      old.slices.length != slices.length ||
      [
        for (var i = 0; i < slices.length; i++) old.slices[i] != slices[i],
      ].any((changed) => changed);
}
