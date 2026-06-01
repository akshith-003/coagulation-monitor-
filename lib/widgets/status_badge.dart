import 'package:flutter/material.dart';
import '../theme/coag_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final String type; // connection, status, measurement_state

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (type) {
      case 'connected':
        color = CoagTheme.statusNormal;
        icon = Icons.bluetooth_connected;
        break;
      case 'connecting':
        color = CoagTheme.statusElevated;
        icon = Icons.bluetooth_searching;
        break;
      case 'disconnected':
        color = CoagTheme.statusHigh;
        icon = Icons.bluetooth_disabled;
        break;
      case 'heating':
        color = CoagTheme.statusElevated;
        icon = Icons.thermostat;
        break;
      case 'insertStrip':
        color = CoagTheme.primary;
        icon = Icons.input;
        break;
      case 'applyBlood':
        color = CoagTheme.secondary;
        icon = Icons.bloodtype;
        break;
      case 'measuring':
        color = CoagTheme.statusTherapeutic;
        icon = Icons.analytics_outlined;
        break;
      case 'completed':
        color = CoagTheme.statusNormal;
        icon = Icons.check_circle_outline;
        break;
      case 'error':
        color = CoagTheme.statusHigh;
        icon = Icons.error_outline;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
