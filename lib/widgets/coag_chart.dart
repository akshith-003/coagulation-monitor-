import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/coag_theme.dart';

class CoagChart extends StatelessWidget {
  final List<double> curvePoints;
  final double? finalPT;
  final bool animate;

  const CoagChart({
    super.key,
    required this.curvePoints,
    this.finalPT,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (curvePoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
              size: 48,
            ),
            const SizedBox(height: 10),
            Text(
              "No measurement data stream",
              style: TextStyle(
                color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Ready to begin monitoring",
              style: TextStyle(
                color: (isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary).withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Convert raw points list into FlSpot coordinates
    // Assuming 10Hz sampling (each point represents 0.1 seconds)
    List<FlSpot> spots = [];
    for (int i = 0; i < curvePoints.length; i++) {
      spots.add(FlSpot(i * 0.1, curvePoints[i]));
    }

    // Calculate dynamic scaling for the chart
    double minX = 0;
    double maxX = max(20.0, spots.last.x);

    double minY = curvePoints.reduce(min);
    double maxY = curvePoints.reduce(max);
    
    // Add safety margins to prevent vertical cramping
    double yDiff = maxY - minY;
    if (yDiff < 100) {
      minY = max(0, minY - 50);
      maxY = maxY + 50;
    } else {
      minY = max(0, minY - (yDiff * 0.1));
      maxY = maxY + (yDiff * 0.1);
    }

    // Colors for the line and area fill
    final lineColors = [
      CoagTheme.primary,
      CoagTheme.secondary,
    ];

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (maxY - minY) / 4,
          verticalInterval: maxX > 30 ? 10 : 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: (maxY - minY) / 3,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: maxX > 30 ? 10 : 5,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value > maxX) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    "${value.toInt()}s",
                    style: TextStyle(
                      color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => isDark ? CoagTheme.surfaceDark : Colors.white,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Time: ${spot.x.toStringAsFixed(1)}s\nSensor: ${spot.y.toInt()}',
                  TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: lineColors),
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: lineColors.map((color) => color.withOpacity(isDark ? 0.15 : 0.08)).toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        // Draw a vertical dotted line highlighting the clotting detection time
        extraLinesData: ExtraLinesData(
          verticalLines: finalPT != null
              ? [
                  VerticalLine(
                    x: finalPT!,
                    color: CoagTheme.statusHigh.withOpacity(0.8),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: const TextStyle(
                        color: CoagTheme.statusHigh,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      labelResolver: (line) => 'Clot: ${finalPT!.toStringAsFixed(1)}s',
                    ),
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}
