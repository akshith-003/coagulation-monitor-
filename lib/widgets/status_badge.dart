import 'package:flutter/material.dart';
import '../theme/coag_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final String type; // measurement stage OR signal quality string

  const StatusBadge({super.key, required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String type) {
    switch (type.toUpperCase()) {
      case 'GOOD': return CoagTheme.signalGood;
      case 'WEAK': return CoagTheme.signalWeak;
      case 'POOR': return CoagTheme.signalPoor;
      case 'DONE':
      case 'COMPLETED': return CoagTheme.signalGood;
      case 'ERROR': return CoagTheme.signalPoor;
      case 'BASELINE':
      case 'INFLATING':
      case 'OCCLUSION':
      case 'ANALYSIS':
        return CoagTheme.primary;
      case 'IDLE': return CoagTheme.textDarkSecondary;
      default: return CoagTheme.textDarkSecondary;
    }
  }
}
