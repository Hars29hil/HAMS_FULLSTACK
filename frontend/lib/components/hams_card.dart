import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HamsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double blur;
  final double borderRadius;

  const HamsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.onTap,
    this.blur = 20.0,
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, // Solid white background
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // Very soft, diffused shadow
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: AppColors.accent.withValues(alpha: 0.1),
          highlightColor: AppColors.surfaceHighlight,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
