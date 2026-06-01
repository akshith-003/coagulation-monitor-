import 'dart:convert';

class MeasurementResult {
  final String id;
  final DateTime timestamp;
  final double pt; // Prothrombin Time in seconds
  final double inr; // International Normalized Ratio
  final double averageTemperature; // Temperature in Celsius during measurement
  final List<double> curvePoints; // Sensor values streamed during measurement

  MeasurementResult({
    required this.id,
    required this.timestamp,
    required this.pt,
    required this.inr,
    required this.averageTemperature,
    required this.curvePoints,
  });

  // Categorize result based on standard INR ranges
  String get status {
    if (inr < 0.8) return 'Low';
    if (inr >= 0.8 && inr <= 1.2) return 'Normal';
    if (inr > 1.2 && inr < 2.0) return 'Elevated';
    if (inr >= 2.0 && inr <= 3.0) return 'Therapeutic';
    if (inr > 3.0 && inr <= 4.0) return 'High';
    return 'Critical';
  }

  // Brief description/advice for each category
  String get healthAdvice {
    switch (status) {
      case 'Low':
        return 'Clotting is faster than normal. Higher risk of clotting.';
      case 'Normal':
        return 'Standard healthy range for individuals not on anticoagulant therapy.';
      case 'Elevated':
        return 'Slightly delayed clotting. Monitor and check with physician.';
      case 'Therapeutic':
        return 'Optimal therapeutic target range for patients on standard anticoagulants.';
      case 'High':
        return 'Significantly delayed clotting. Increased risk of minor bleeding.';
      case 'Critical':
        return 'CRITICAL: High risk of spontaneous bleeding. Contact medical provider immediately.';
      default:
        return 'Unknown status.';
    }
  }

  // Convert map representation to object
  factory MeasurementResult.fromMap(Map<String, dynamic> map) {
    return MeasurementResult(
      id: map['id'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      pt: (map['pt'] as num).toDouble(),
      inr: (map['inr'] as num).toDouble(),
      averageTemperature: (map['averageTemperature'] as num).toDouble(),
      curvePoints: List<double>.from((map['curvePoints'] as List? ?? []).map((e) => (e as num).toDouble())),
    );
  }

  // Convert object to map representation
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'pt': pt,
      'inr': inr,
      'averageTemperature': averageTemperature,
      'curvePoints': curvePoints,
    };
  }

  // JSON encoding/decoding helpers
  String toJson() => json.encode(toMap());
  factory MeasurementResult.fromJson(String source) => MeasurementResult.fromMap(json.decode(source));
}
