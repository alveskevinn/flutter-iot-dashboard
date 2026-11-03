import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/device.dart';

/// Line chart of a time series with optional dashed alert limits.
class SeriesChart extends StatelessWidget {
  const SeriesChart({super.key, required this.readings, this.min, this.max, this.unit = ''});

  final List<Reading> readings;
  final double? min;
  final double? max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (readings.length < 2) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text('Waiting for data…', style: TextStyle(color: theme.colorScheme.outline)),
        ),
      );
    }

    final spots = [for (final r in readings) FlSpot(r.ts.millisecondsSinceEpoch.toDouble(), r.value)];
    final first = spots.first.x, last = spots.last.x;
    final span = last - first;
    final timeFmt = span > const Duration(hours: 6).inMilliseconds ? DateFormat.Hm() : DateFormat.Hms();
    final limitColor = const Color(0xFFF85149).withValues(alpha: 0.6);

    HorizontalLine limit(double y) =>
        HorizontalLine(y: y, color: limitColor, strokeWidth: 1.5, dashArray: const [6, 4]);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: first,
          maxX: last,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: 2,
              color: theme.colorScheme.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [if (min != null) limit(min!), if (max != null) limit(max!)],
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(meta.formattedValue, style: theme.textTheme.labelSmall),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: span > 0 ? span / 4 : null,
                // The edges are already covered by the interval ticks; including
                // them again makes the last two labels overlap.
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    timeFmt.format(DateTime.fromMillisecondsSinceEpoch(v.toInt())),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.y.toStringAsFixed(2)} $unit\n'
                    '${DateFormat.MMMd().add_Hm().format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}',
                    theme.textTheme.labelSmall!,
                  ),
              ],
            ),
          ),
        ),
        duration: Duration.zero,
      ),
    );
  }
}
