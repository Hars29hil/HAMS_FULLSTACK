import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeType { success, warning, danger, info, defaultBadge }

class HamsBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const HamsBadge({super.key, required this.label, this.type = BadgeType.defaultBadge});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (type) {
      case BadgeType.success:
        bgColor = AppColors.greenSoft;
        textColor = AppColors.green;
        break;
      case BadgeType.warning:
        bgColor = AppColors.amberSoft;
        textColor = AppColors.amber;
        break;
      case BadgeType.danger:
        bgColor = AppColors.redSoft;
        textColor = AppColors.red;
        break;
      case BadgeType.info:
        bgColor = AppColors.tealSoft;
        textColor = AppColors.teal;
        break;
      case BadgeType.defaultBadge:
        bgColor = AppColors.bgElevated;
        textColor = AppColors.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
