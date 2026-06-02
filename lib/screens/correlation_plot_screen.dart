import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../managers/coagulation_manager.dart';
import '../theme/coag_theme.dart';

class CorrelationPlotScreen extends StatelessWidget {
  const CorrelationPlotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final manager = context.watch<CoagulationManager>();
    final data = manager.correlationData; // List<[gammaAsymptote, labInr]>

    // Linear regression: y = a + b*x
    double rSquared = 0;
    double slope = 0;
    double intercept = 0;
    if (data.length >= 2) {
      final n = data.length.toDouble();
      final sumX = data.map((p) => p[0]).reduce((a, b) => a + b);
      final sumY = data.map((p) => p[1]).reduce((a, b) => a + b);
      final sumXY = data.map((p) => p[0] * p[1]).reduce((a, b) => a + b);
      final sumX2 = data.map((p) => p[0] * p[0]).reduce((a, b) => a + b);
      slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
      intercept = (sumY - slope * sumX) / n;
      final meanY = sumY / n;
      final ssTot = data.map((p) => pow(p[1] - meanY, 2)).reduce((a, b) => a + b);
      final ssRes = data.map((p) => pow(p[1] - (intercept + slope * p[0]), 2)).reduce((a, b) => a + b);
      rSquared = ssTot > 0 ? 1 - ssRes / ssTot : 0;
    }

    final spots = data.map((p) => FlSpot(p[0], p[1])).toList();

    // Regression line points
    List<FlSpot> regressionLine = [];
    if (data.isNotEmpty) {
      final minX = data.map((p) => p[0]).reduce(min);
      final maxX = data.map((p) => p[0]).reduce(max);
      regressionLine = [
        FlSpot(minX, intercept + slope * minX),
        FlSpot(maxX, intercept + slope * maxX),
      ];
    }

    return Scaffold(
      backgroundColor: isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? CoagTheme.surfaceDark : Colors.white,
        title: const Text('Γ vs Lab INR Correlation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // R² badge
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CoagTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CoagTheme.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Text('R² = ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(rSquared.toStringAsFixed(4),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: CoagTheme.primary)),
                ]),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${data.length} paired measurements',
                    style: TextStyle(fontSize: 12, color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
                Text('y = ${slope.toStringAsFixed(4)}x + ${intercept.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: CoagTheme.accentCyan)),
              ]),
            ]),
            const SizedBox(height: 20),

            // Scatter plot
            Expanded(
              child: ScatterChart(
                ScatterChartData(
                  scatterSpots: spots.map((s) => ScatterSpot(
                    s.x, s.y,
                    dotPainter: FlDotCirclePainter(
                      radius: 6,
                      color: CoagTheme.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  )).toList(),
                  minX: spots.isEmpty ? 0 : spots.map((s) => s.x).reduce(min) - 5,
                  maxX: spots.isEmpty ? 60 : spots.map((s) => s.x).reduce(max) + 5,
                  minY: 0,
                  maxY: spots.isEmpty ? 5 : spots.map((s) => s.y).reduce(max) + 0.5,
                  gridData: FlGridData(
                    show: true,
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
                      axisNameWidget: const RotatedBox(quarterTurns: 3,
                          child: Text('Lab INR', style: TextStyle(fontSize: 10, color: Colors.grey))),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, m) => SideTitleWidget(
                          axisSide: m.axisSide,
                          child: Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Gamma Asymptote (Hz)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) => SideTitleWidget(
                          axisSide: m.axisSide,
                          child: Text('${v.toInt()} Hz', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  scatterTouchData: ScatterTouchData(
                    touchTooltipData: ScatterTouchTooltipData(
                      getTooltipColor: (_) => isDark ? CoagTheme.surfaceDark : Colors.white,
                      getTooltipItems: (sp) => ScatterTooltipItem(
                        'Γ∞: ${sp.x.toStringAsFixed(1)} Hz\nINR: ${sp.y.toStringAsFixed(2)}',
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        bottomMargin: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              'Scatter plot showing Gamma Asymptote vs paired Lab INR. '
              'A stronger negative R² indicates better DLS correlation with coagulation status.',
              style: TextStyle(fontSize: 10, color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
