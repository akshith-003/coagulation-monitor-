import 'dart:convert';

/// Represents a complete DLS measurement result, including raw physics data,
/// environmental readings, and optional paired lab calibration values.
class DlsMeasurementResult {
  final String id; // e.g. "CM-001"
  final DateTime timestamp;

  // --- DLS Physics Results ---
  final double gammaInitial; // Hz
  final double gammaAsymptote; // Hz — key diagnostic value
  final double gammaDrop; // Hz (gammaInitial - gammaAsymptote)
  final double decayRate; // Hz/s
  final double sMobility; // arbitrary units
  final String decayShape; // "FAST" / "MODERATE" / "SLOW"

  // --- Environmental ---
  final double dcIntensity; // Volts
  final double skinTempC; // Celsius
  final double peakPressureMmhg; // mmHg
  final String signalQuality; // "GOOD" / "WEAK" / "POOR"
  final double durationSeconds;

  // --- Raw Data Points (for replay) ---
  final List<double> adcRawPoints;
  final List<double> gammaPoints;

  // --- Optional Calibration Data (entered by user after measurement) ---
  final double? labInr;
  final int? patientAge;
  final bool onWarfarin;
  final bool onAspirin;
  final String medications;
  final String notes;

  DlsMeasurementResult({
    required this.id,
    required this.timestamp,
    required this.gammaInitial,
    required this.gammaAsymptote,
    required this.gammaDrop,
    required this.decayRate,
    required this.sMobility,
    required this.decayShape,
    required this.dcIntensity,
    required this.skinTempC,
    required this.peakPressureMmhg,
    required this.signalQuality,
    required this.durationSeconds,
    required this.adcRawPoints,
    required this.gammaPoints,
    this.labInr,
    this.patientAge,
    this.onWarfarin = false,
    this.onAspirin = false,
    this.medications = '',
    this.notes = '',
  });

  /// Coagulation tendency zone based on gammaAsymptote
  String get coagTendency {
    if (gammaAsymptote > 38) return 'HYPO';
    if (gammaAsymptote >= 22) return 'NORMAL';
    return 'HYPER';
  }

  /// Human-readable interpretation string
  String get interpretation {
    switch (coagTendency) {
      case 'HYPO':
        return 'RBC mobility suggests hypo-coagulable state (consistent with anticoagulant therapy)';
      case 'HYPER':
        return 'RBC mobility suggests hyper-coagulable state';
      default:
        return 'RBC mobility suggests normal coagulation tendency';
    }
  }

  /// Copy with updated calibration fields
  DlsMeasurementResult copyWith({
    double? labInr,
    int? patientAge,
    bool? onWarfarin,
    bool? onAspirin,
    String? medications,
    String? notes,
  }) {
    return DlsMeasurementResult(
      id: id,
      timestamp: timestamp,
      gammaInitial: gammaInitial,
      gammaAsymptote: gammaAsymptote,
      gammaDrop: gammaDrop,
      decayRate: decayRate,
      sMobility: sMobility,
      decayShape: decayShape,
      dcIntensity: dcIntensity,
      skinTempC: skinTempC,
      peakPressureMmhg: peakPressureMmhg,
      signalQuality: signalQuality,
      durationSeconds: durationSeconds,
      adcRawPoints: adcRawPoints,
      gammaPoints: gammaPoints,
      labInr: labInr ?? this.labInr,
      patientAge: patientAge ?? this.patientAge,
      onWarfarin: onWarfarin ?? this.onWarfarin,
      onAspirin: onAspirin ?? this.onAspirin,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gammaInitial': gammaInitial,
      'gammaAsymptote': gammaAsymptote,
      'gammaDrop': gammaDrop,
      'decayRate': decayRate,
      'sMobility': sMobility,
      'decayShape': decayShape,
      'dcIntensity': dcIntensity,
      'skinTempC': skinTempC,
      'peakPressureMmhg': peakPressureMmhg,
      'signalQuality': signalQuality,
      'durationSeconds': durationSeconds,
      'adcRawPoints': adcRawPoints,
      'gammaPoints': gammaPoints,
      'labInr': labInr,
      'patientAge': patientAge,
      'onWarfarin': onWarfarin,
      'onAspirin': onAspirin,
      'medications': medications,
      'notes': notes,
    };
  }

  factory DlsMeasurementResult.fromMap(Map<String, dynamic> map) {
    return DlsMeasurementResult(
      id: map['id'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      gammaInitial: (map['gammaInitial'] as num).toDouble(),
      gammaAsymptote: (map['gammaAsymptote'] as num).toDouble(),
      gammaDrop: (map['gammaDrop'] as num).toDouble(),
      decayRate: (map['decayRate'] as num).toDouble(),
      sMobility: (map['sMobility'] as num).toDouble(),
      decayShape: map['decayShape'] ?? 'MODERATE',
      dcIntensity: (map['dcIntensity'] as num).toDouble(),
      skinTempC: (map['skinTempC'] as num).toDouble(),
      peakPressureMmhg: (map['peakPressureMmhg'] as num).toDouble(),
      signalQuality: map['signalQuality'] ?? 'GOOD',
      durationSeconds: (map['durationSeconds'] as num).toDouble(),
      adcRawPoints: List<double>.from(
          (map['adcRawPoints'] as List? ?? []).map((e) => (e as num).toDouble())),
      gammaPoints: List<double>.from(
          (map['gammaPoints'] as List? ?? []).map((e) => (e as num).toDouble())),
      labInr: map['labInr'] != null ? (map['labInr'] as num).toDouble() : null,
      patientAge: map['patientAge'] as int?,
      onWarfarin: map['onWarfarin'] ?? false,
      onAspirin: map['onAspirin'] ?? false,
      medications: map['medications'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());
  factory DlsMeasurementResult.fromJson(String source) =>
      DlsMeasurementResult.fromMap(json.decode(source));

  /// Generate a CSV header row
  static String csvHeader() {
    return 'measurement_id,timestamp,gamma_initial,gamma_asymptote,gamma_drop,'
        'decay_rate,s_mobility,decay_shape,dc_intensity,skin_temp_c,'
        'peak_pressure_mmhg,signal_quality,duration_s,'
        'lab_inr,patient_age,on_warfarin,on_aspirin,medications,notes';
  }

  /// Generate this result as a CSV row
  String toCsvRow() {
    String escape(String s) => '"${s.replaceAll('"', '""')}"';
    return '$id,${timestamp.toIso8601String()},'
        '${gammaInitial.toStringAsFixed(2)},'
        '${gammaAsymptote.toStringAsFixed(2)},'
        '${gammaDrop.toStringAsFixed(2)},'
        '${decayRate.toStringAsFixed(3)},'
        '${sMobility.toStringAsFixed(0)},'
        '$decayShape,$dcIntensity,$skinTempC,$peakPressureMmhg,'
        '$signalQuality,${durationSeconds.toStringAsFixed(1)},'
        '${labInr?.toStringAsFixed(2) ?? ''},'
        '${patientAge ?? ''},'
        '${onWarfarin ? 'YES' : 'NO'},'
        '${onAspirin ? 'YES' : 'NO'},'
        '${escape(medications)},'
        '${escape(notes)}';
  }
}
