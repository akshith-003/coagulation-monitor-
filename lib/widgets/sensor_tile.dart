import 'package:flutter/material.dart';
import '../theme/coag_theme.dart';

/// A single sensor reading tile used in the 2x2 live sensor grid.
class SensorTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final bool isDark;
  final Color? accentColor;

  const SensorTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? CoagTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.cardDark : CoagTheme.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: isDark
                        ? CoagTheme.textDarkSecondary
                        : CoagTheme.textLightSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? CoagTheme.textDarkPrimary
                      : CoagTheme.textLightPrimary,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? CoagTheme.textDarkSecondary
                        : CoagTheme.textLightSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
