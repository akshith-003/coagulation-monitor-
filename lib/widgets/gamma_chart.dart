import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/coag_theme.dart';

/// Gamma Decay (Γ Hz) chart — shows exponential decay of DLS gamma signal
/// over the 20s occlusion window. Shows a dashed asymptote line once detected.
class GammaChart extends StatelessWidget {
  final List<double> gammaPoints; // one per 100ms = 10Hz
  final double? asymptote; // Hz — shown as dashed line when detected

  const GammaChart({
    super.key,
    required this.gammaPoints,
    this.asymptote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gammaPoints.isEmpty) {
      return Center(
        child: Text(
          'Waiting for occlusion...',
          style: TextStyle(
            color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
            fontSize: 13,
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < gammaPoints.length; i++) {
      spots.add(FlSpot(i * 0.1, gammaPoints[i]));
    }

    final extraLines = <HorizontalLine>[];
    if (asymptote != null) {
      extraLines.add(HorizontalLine(
        y: asymptote!,
        color: CoagTheme.accentCyan.withOpacity(0.7),
        strokeWidth: 1.5,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: const TextStyle(
            color: CoagTheme.accentCyan,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          labelResolver: (line) => 'Γ∞ ${asymptote!.toStringAsFixed(1)} Hz',
        ),
      ));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 20,
        minY: 0,
        maxY: 65,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: 5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Hz', style: TextStyle(fontSize: 9, color: Colors.grey)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 15,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('time (s)', style: TextStyle(fontSize: 9, color: Colors.grey)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 5,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    '${value.toInt()}s',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
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
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: CoagTheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: CoagTheme.primary.withOpacity(0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? CoagTheme.surfaceDark : Colors.white,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.x.toStringAsFixed(1)}s\n${s.y.toStringAsFixed(1)} Hz',
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
