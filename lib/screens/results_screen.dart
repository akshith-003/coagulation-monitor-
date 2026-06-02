import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/coagulation_manager.dart';
import '../models/measurement_result.dart';
import '../theme/coag_theme.dart';
import '../widgets/coag_tendency_bar.dart';
import '../widgets/status_badge.dart';

class ResultsScreen extends StatefulWidget {
  final DlsMeasurementResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late DlsMeasurementResult _result;
  bool _isDark = true;

  // Form controllers
  final _labInrController = TextEditingController();
  final _ageController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _onWarfarin = false;
  bool _onAspirin = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  @override
  void dispose() {
    _labInrController.dispose();
    _ageController.dispose();
    _medicationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
      appBar: AppBar(
        backgroundColor: _isDark ? CoagTheme.surfaceDark : Colors.white,
        title: Column(
          children: [
            const Text('Measurement Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_result.id,
                style: TextStyle(
                    fontSize: 12,
                    color: _isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Section A — DLS Raw Results
            _buildSectionA(),
            const SizedBox(height: 14),

            // Section B — Environmental
            _buildSectionB(),
            const SizedBox(height: 14),

            // Section C — Coagulation Tendency
            _buildSectionC(),
            const SizedBox(height: 14),

            // Section D — Calibration Data Entry
            _buildSectionD(context),
          ],
        ),
      ),
    );
  }

  // ─────────── Section A: DLS Raw Results ───────────
  Widget _buildSectionA() {
    return _ResultCard(
      isDark: _isDark,
      title: 'DLS MEASUREMENT RESULTS',
      icon: Icons.biotech_rounded,
      iconColor: CoagTheme.primary,
      children: [
        _DataRow('Gamma Initial', '${_result.gammaInitial.toStringAsFixed(2)} Hz'),
        _DataRow('Gamma Asymptote', '${_result.gammaAsymptote.toStringAsFixed(2)} Hz',
            highlight: true, highlightColor: CoagTheme.getTendencyColor(_result.coagTendency)),
        _DataRow('Gamma Drop', '${_result.gammaDrop.toStringAsFixed(2)} Hz'),
        _DataRow('Decay Rate', '${_result.decayRate.toStringAsFixed(3)} Hz/s'),
        _DataRow('S Mobility Index', '${_result.sMobility.toStringAsFixed(0)} au'),
        _DataRow('Decay Shape', _result.decayShape),
      ],
    );
  }

  // ─────────── Section B: Environmental ───────────
  Widget _buildSectionB() {
    return _ResultCard(
      isDark: _isDark,
      title: 'ENVIRONMENTAL',
      icon: Icons.thermostat_rounded,
      iconColor: CoagTheme.signalWeak,
      children: [
        _DataRow('Skin Temperature', '${_result.skinTempC.toStringAsFixed(1)}°C'),
        _DataRow('Peak Pressure', '${_result.peakPressureMmhg.toStringAsFixed(0)} mmHg'),
        _DataRow('DC Intensity', '${_result.dcIntensity.toStringAsFixed(3)} V'),
        _DataRow('Signal Quality', _result.signalQuality,
            trailingWidget: StatusBadge(label: _result.signalQuality, type: _result.signalQuality)),
        _DataRow('Duration', '${_result.durationSeconds.toStringAsFixed(1)} s'),
      ],
    );
  }

  // ─────────── Section C: Coagulation Tendency ───────────
  Widget _buildSectionC() {
    final tendencyColor = CoagTheme.getTendencyColor(_result.coagTendency);
    return _ResultCard(
      isDark: _isDark,
      title: 'COAGULATION TENDENCY',
      icon: Icons.water_drop_rounded,
      iconColor: tendencyColor,
      children: [
        const SizedBox(height: 4),
        CoagTendencyBar(gammaAsymptote: _result.gammaAsymptote),
        const SizedBox(height: 16),
        // Interpretation text
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tendencyColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tendencyColor.withOpacity(0.2)),
          ),
          child: Text(
            _result.interpretation,
            style: TextStyle(
                color: tendencyColor, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        // Disclaimer
        Text(
          'Research prototype only. Not validated for clinical diagnosis. '
          'All interpretations require confirmation by laboratory testing.',
          style: TextStyle(
            fontSize: 10,
            color: (_isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)
                .withOpacity(0.7),
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─────────── Section D: Calibration Data Entry ───────────
  Widget _buildSectionD(BuildContext context) {
    final labInrEmpty = _labInrController.text.trim().isEmpty;

    return _ResultCard(
      isDark: _isDark,
      title: 'CALIBRATION DATA ENTRY',
      icon: Icons.science_rounded,
      iconColor: CoagTheme.accentCyan,
      subtitle: 'Enter paired lab values to build INR correlation dataset',
      children: [
        // Measurement ID + Timestamp (auto-filled, read-only)
        Row(children: [
          Expanded(child: _InfoChip('ID', _result.id, _isDark)),
          const SizedBox(width: 8),
          Expanded(
              child: _InfoChip(
                  'Time',
                  '${_result.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${_result.timestamp.minute.toString().padLeft(2, '0')}',
                  _isDark)),
        ]),
        const SizedBox(height: 16),

        // Lab INR — highlighted in amber if empty
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: labInrEmpty
                  ? CoagTheme.signalWeak.withOpacity(0.6)
                  : CoagTheme.primary.withOpacity(0.4),
              width: labInrEmpty ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _labInrController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Lab INR (OPTIONAL — builds calibration dataset)',
              labelStyle: TextStyle(
                fontSize: 12,
                color: labInrEmpty ? CoagTheme.signalWeak : CoagTheme.primary,
              ),
              hintText: '0.5 – 8.0',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: labInrEmpty
                  ? Tooltip(
                      message: 'Entering lab INR builds your calibration dataset',
                      child: Icon(Icons.info_outline, size: 16, color: CoagTheme.signalWeak),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 10),

        // Patient Age
        _buildTextField(_ageController, 'Patient Age',
            keyboardType: TextInputType.number),
        const SizedBox(height: 10),

        // Warfarin / Aspirin toggles
        Row(children: [
          Expanded(
            child: _ToggleChip(
              label: 'On Warfarin',
              value: _onWarfarin,
              isDark: _isDark,
              onChanged: (v) => setState(() => _onWarfarin = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ToggleChip(
              label: 'On Aspirin',
              value: _onAspirin,
              isDark: _isDark,
              onChanged: (v) => setState(() => _onAspirin = v),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Other medications
        _buildTextField(_medicationsController, 'Other medications (optional)'),
        const SizedBox(height: 10),

        // Clinical notes
        _buildTextField(_notesController, 'Clinical notes', maxLines: 3),
        const SizedBox(height: 20),

        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _isDark ? Colors.white60 : Colors.black54,
                side: BorderSide(
                    color: _isDark ? Colors.white24 : Colors.black26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('DISCARD'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _saveDataset(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoagTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SAVE TO DATASET',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Future<void> _saveDataset(BuildContext context) async {
    setState(() => _saving = true);
    final manager = context.read<CoagulationManager>();

    double? labInr;
    final inrText = _labInrController.text.trim();
    if (inrText.isNotEmpty) {
      labInr = double.tryParse(inrText);
      if (labInr == null || labInr < 0.5 || labInr > 8.0) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lab INR must be between 0.5 and 8.0'),
            backgroundColor: CoagTheme.signalPoor,
          ),
        );
        return;
      }
    }

    final saved = _result.copyWith(
      labInr: labInr,
      patientAge: int.tryParse(_ageController.text.trim()),
      onWarfarin: _onWarfarin,
      onAspirin: _onAspirin,
      medications: _medicationsController.text.trim(),
      notes: _notesController.text.trim(),
    );

    await manager.saveResult(saved);
    setState(() => _saving = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.id} saved to dataset'),
          backgroundColor: CoagTheme.signalGood,
        ),
      );
      Navigator.pop(context);
    }
  }
}

// ─────────────────────────────────────────────
// Shared result card widget
// ─────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final List<Widget> children;

  const _ResultCard({
    required this.isDark,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 11,
                    color: (isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)
                        .withOpacity(0.7))),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? highlightColor;
  final Widget? trailingWidget;

  const _DataRow(this.label, this.value,
      {this.highlight = false, this.highlightColor, this.trailingWidget});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
          trailingWidget ??
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: highlight
                      ? highlightColor
                      : (isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary),
                ),
              ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _InfoChip(this.label, this.value, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.cardDark : CoagTheme.cardLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
          Text(value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;
  const _ToggleChip(
      {required this.label, required this.value, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? CoagTheme.primary.withOpacity(0.15)
              : (isDark ? CoagTheme.cardDark : CoagTheme.cardLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value ? CoagTheme.primary : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: value ? CoagTheme.primary : null)),
            Text(value ? 'YES' : 'NO',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: value ? CoagTheme.primary : CoagTheme.textDarkSecondary)),
          ],
        ),
      ),
    );
  }
}
