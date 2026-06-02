import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/coagulation_manager.dart';
import '../models/measurement_result.dart';
import '../theme/coag_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/gamma_chart.dart';
import 'correlation_plot_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<CoagulationManager>(
      builder: (context, manager, _) {
        final history = manager.history;
        final withInr = history.where((r) => r.labInr != null).length;
        final hasCorrelation = withInr >= 10;

        double? gammaMin, gammaMax, inrMin, inrMax;
        if (history.isNotEmpty) {
          gammaMin = history.map((r) => r.gammaAsymptote).reduce((a, b) => a < b ? a : b);
          gammaMax = history.map((r) => r.gammaAsymptote).reduce((a, b) => a > b ? a : b);
        }
        final inrList = history.where((r) => r.labInr != null).map((r) => r.labInr!).toList();
        if (inrList.isNotEmpty) {
          inrMin = inrList.reduce((a, b) => a < b ? a : b);
          inrMax = inrList.reduce((a, b) => a > b ? a : b);
        }

        return Column(children: [
          // Summary bar
          Container(
            color: isDark ? CoagTheme.surfaceDark : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SumStat('Total', history.length.toString()),
                _SumStat('With INR', withInr.toString()),
                _SumStat('Γ range',
                    gammaMin != null ? '${gammaMin.toStringAsFixed(0)}-${gammaMax!.toStringAsFixed(0)} Hz' : '—'),
                _SumStat('INR range',
                    inrMin != null ? '${inrMin.toStringAsFixed(1)}-${inrMax!.toStringAsFixed(1)}' : '—'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history_toggle_off_rounded, size: 56,
                          color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary),
                      const SizedBox(height: 12),
                      const Text('No measurements yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Complete a measurement cycle to see results here.',
                          style: TextStyle(fontSize: 12,
                              color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                    itemCount: history.length,
                    itemBuilder: (ctx, i) => _HistoryCard(result: history[i], isDark: isDark),
                  ),
          ),
          // Bottom buttons
          Container(
            color: isDark ? CoagTheme.surfaceDark : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: history.isEmpty ? null : () => _exportCsv(context, manager),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('EXPORT CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CoagTheme.primary),
                    foregroundColor: CoagTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasCorrelation
                      ? () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(
                              value: manager, child: const CorrelationPlotScreen())))
                      : null,
                  icon: const Icon(Icons.scatter_plot_rounded, size: 18),
                  label: Text(
                    hasCorrelation ? 'CORRELATION' : 'NEED ${10 - withInr} INR',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoagTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? CoagTheme.cardDark : CoagTheme.cardLight,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  void _exportCsv(BuildContext context, CoagulationManager manager) {
    final csv = manager.buildCsv();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${manager.history.length} records ready to export.', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(
              csv.split('\n').take(4).join('\n') + '\n...',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.greenAccent),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Select all text above to copy to clipboard.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String label;
  final String value;
  const _SumStat(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: CoagTheme.primary)),
      Text(label, style: TextStyle(fontSize: 9, letterSpacing: 0.4,
          color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
    ]);
  }
}

class _HistoryCard extends StatelessWidget {
  final DlsMeasurementResult result;
  final bool isDark;
  const _HistoryCard({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tc = CoagTheme.getTendencyColor(result.coagTendency);
    final ts = result.timestamp;
    return Dismissible(
      key: Key(result.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CoagTheme.signalPoor,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        context.read<CoagulationManager>().deleteHistoryItem(result.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result.id} deleted'),
          backgroundColor: isDark ? CoagTheme.surfaceDark : CoagTheme.cardLight,
        ));
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => _DetailScreen(result: result))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? CoagTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)),
          boxShadow: CoagTheme.getCardShadow(isDark),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(result.id, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: CoagTheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')}  ${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}',
              style: TextStyle(fontSize: 11, color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary),
            )),
            StatusBadge(label: result.signalQuality, type: result.signalQuality),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _KV('Γ∞', '${result.gammaAsymptote.toStringAsFixed(1)} Hz', CoagTheme.primary),
            const SizedBox(width: 14),
            _KV('S', '${result.sMobility.toStringAsFixed(0)} au', CoagTheme.accentCyan),
            const SizedBox(width: 14),
            _KV('INR', result.labInr != null ? result.labInr!.toStringAsFixed(2) : '—',
                result.labInr != null ? CoagTheme.signalGood : CoagTheme.textDarkSecondary),
            if (result.patientAge != null) ...[
              const SizedBox(width: 14),
              _KV('Age', '${result.patientAge}', CoagTheme.textDarkSecondary),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: tc.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text('[${result.coagTendency} zone]',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc)),
            ),
            if (result.onWarfarin) ...[
              const SizedBox(width: 8),
              Text('Warfarin: YES', style: TextStyle(fontSize: 10,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
            ],
          ]),
        ]),
      ),
    ));
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KV(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(children: [
    TextSpan(text: '$label: ', style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
    TextSpan(text: value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
  ]));
}

class _DetailScreen extends StatelessWidget {
  final DlsMeasurementResult result;
  const _DetailScreen({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = result.timestamp;
    return Scaffold(
      backgroundColor: isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? CoagTheme.surfaceDark : Colors.white,
        title: Text(result.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: CoagTheme.signalPoor),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Measurement?', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Text('Are you sure you want to delete ${result.id}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                    TextButton(
                      onPressed: () {
                        context.read<CoagulationManager>().deleteHistoryItem(result.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('DELETE', style: TextStyle(color: CoagTheme.signalPoor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _buildCard(isDark, [
            _R('Timestamp', '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')} ${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}', isDark),
            _R('Gamma Initial', '${result.gammaInitial.toStringAsFixed(2)} Hz', isDark),
            _R('Gamma Asymptote', '${result.gammaAsymptote.toStringAsFixed(2)} Hz', isDark, CoagTheme.getTendencyColor(result.coagTendency)),
            _R('Gamma Drop', '${result.gammaDrop.toStringAsFixed(2)} Hz', isDark),
            _R('S Mobility', '${result.sMobility.toStringAsFixed(0)} au', isDark),
            _R('Decay Shape', result.decayShape, isDark),
            _R('DC Intensity', '${result.dcIntensity.toStringAsFixed(3)} V', isDark),
            _R('Skin Temp', '${result.skinTempC.toStringAsFixed(1)}°C', isDark),
            _R('Peak Pressure', '${result.peakPressureMmhg.toStringAsFixed(0)} mmHg', isDark),
            if (result.labInr != null) _R('Lab INR', result.labInr!.toStringAsFixed(2), isDark, CoagTheme.signalGood),
            if (result.patientAge != null) _R('Patient Age', '${result.patientAge}', isDark),
            _R('Warfarin', result.onWarfarin ? 'YES' : 'NO', isDark),
            _R('Aspirin', result.onAspirin ? 'YES' : 'NO', isDark),
            if (result.medications.isNotEmpty) _R('Medications', result.medications, isDark),
            if (result.notes.isNotEmpty) _R('Notes', result.notes, isDark),
          ]),
          if (result.gammaPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? CoagTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gamma Decay Replay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
                const SizedBox(height: 6),
                Expanded(child: GammaChart(gammaPoints: result.gammaPoints, asymptote: result.gammaAsymptote)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? CoagTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
    ),
    child: Column(children: children),
  );

  Widget _R(String label, String value, bool isDark, [Color? color]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12,
          color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
          color: color ?? (isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary))),
    ]),
  );
}
