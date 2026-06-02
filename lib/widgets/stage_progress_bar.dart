import 'package:flutter/material.dart';
import '../theme/coag_theme.dart';

/// Horizontal 5-step stage progress bar for measurement flow.
/// Stages: baseline → inflating → occlusion → analysis → done
class StageProgressBar extends StatelessWidget {
  final String currentStage;

  const StageProgressBar({super.key, required this.currentStage});

  static const _stages = ['baseline', 'inflating', 'occlusion', 'analysis', 'done'];
  static const _labels = ['BASELINE', 'INFLATING', 'OCCLUSION', 'ANALYSIS', 'DONE'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexOf(currentStage.toLowerCase());
    return Row(
      children: List.generate(_stages.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line between steps
          final stageIndex = i ~/ 2;
          final passed = currentIndex > stageIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: passed
                  ? CoagTheme.primary
                  : CoagTheme.textDarkSecondary.withOpacity(0.3),
            ),
          );
        }
        final stageIndex = i ~/ 2;
        final isActive = stageIndex == currentIndex;
        final isPassed = stageIndex < currentIndex;
        return _StageStep(
          label: _labels[stageIndex],
          isActive: isActive,
          isPassed: isPassed,
        );
      }),
    );
  }
}

class _StageStep extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isPassed;

  const _StageStep({
    required this.label,
    required this.isActive,
    required this.isPassed,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color textColor;

    if (isActive) {
      dotColor = CoagTheme.primary;
      textColor = CoagTheme.primary;
    } else if (isPassed) {
      dotColor = CoagTheme.signalGood;
      textColor = CoagTheme.signalGood;
    } else {
      dotColor = CoagTheme.textDarkSecondary.withOpacity(0.4);
      textColor = CoagTheme.textDarkSecondary.withOpacity(0.5);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 12 : 8,
          height: isActive ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: CoagTheme.primary.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: textColor,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
