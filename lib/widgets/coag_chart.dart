import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/coag_theme.dart';

/// Rolling ADC raw signal chart — cyan line, 5s window, Y=0-4096
class CoagChart extends StatelessWidget {
  final List<double> curvePoints; // rolling 50 points max (5s at 10Hz)
  final double? finalPT; // legacy, unused in DLS mode

  const CoagChart({
    super.key,
    required this.curvePoints,
    this.finalPT,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (curvePoints.isEmpty) {
      return Center(
        child: Text(
          'Waiting for signal...',
          style: TextStyle(
            color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    // Map to FlSpot with rolling 5s window
    // Most recent point = rightmost; each tick = 0.1s apart
    final count = curvePoints.length;
    final spots = <FlSpot>[];
    for (int i = 0; i < count; i++) {
      final t = (i - count + 50) * 0.1; // time offset so latest = 5.0s
      spots.add(FlSpot(t.clamp(-5.0, 5.0), curvePoints[i]));
    }

    return LineChart(
      LineChartData(
        minX: -5,
        maxX: 0,
        minY: 0,
        maxY: 4096,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1024,
          verticalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('counts', style: TextStyle(fontSize: 9, color: Colors.grey)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: 1024,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('rolling 5s', style: TextStyle(fontSize: 9, color: Colors.grey)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    '${value.toInt()}s',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: CoagTheme.accentCyan,
            barWidth: 1.8,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: CoagTheme.accentCyan.withOpacity(0.08),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
