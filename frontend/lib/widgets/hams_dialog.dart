import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

enum HamsDialogType { error, success, confirm, info }

class HamsDialog extends StatelessWidget {
  final HamsDialogType type;
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  const HamsDialog({
    super.key,
    required this.type,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    Color ringBgColor;
    Color ringColor;
    Color ringShadowColor;
    IconData icon;

    switch (type) {
      case HamsDialogType.error:
        ringBgColor = AppColors.red.withValues(alpha: 0.10);
        ringColor = AppColors.red;
        ringShadowColor = AppColors.red.withValues(alpha: 0.06);
        icon = LucideIcons.xCircle;
        break;
      case HamsDialogType.success:
        ringBgColor = AppColors.green.withValues(alpha: 0.10);
        ringColor = AppColors.green;
        ringShadowColor = AppColors.green.withValues(alpha: 0.06);
        icon = LucideIcons.checkCircle2;
        break;
      case HamsDialogType.confirm:
        ringBgColor = AppColors.amber.withValues(alpha: 0.10);
        ringColor = AppColors.amber;
        ringShadowColor = AppColors.amber.withValues(alpha: 0.06);
        icon = LucideIcons.alertTriangle;
        break;
      case HamsDialogType.info:
        ringBgColor = AppColors.teal.withValues(alpha: 0.10);
        ringColor = AppColors.teal;
        ringShadowColor = AppColors.teal.withValues(alpha: 0.06);
        icon = LucideIcons.info;
        break;
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF28200E).withValues(alpha: 0.28),
                blurRadius: 60,
                spreadRadius: -20,
                offset: const Offset(0, 30),
              ),
              BoxShadow(
                color: const Color(0xFF28200E).withValues(alpha: 0.14),
                blurRadius: 16,
                spreadRadius: -8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ring
              Container(
                width: 54,
                height: 54,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ringBgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ringShadowColor,
                      blurRadius: 0,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: ringColor,
                    size: 24,
                  ),
                ),
              ),
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              // Message
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              // Content
              if (content != null) ...[
                const SizedBox(height: 14),
                content!,
              ],
              // Actions
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: actions.map((action) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: action == actions.first ? 0 : 5,
                        right: action == actions.last ? 0 : 5,
                      ),
                      child: action,
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showHamsDialog<T>({
  required BuildContext context,
  required HamsDialogType type,
  required String title,
  String? message,
  Widget? content,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent, // We handle background in pageBuilder
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          // Radial Gradient Background
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (barrierDismissible) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE4E1D6), // Base background from HTML
                  gradient: RadialGradient(
                    center: Alignment(0.0, -1.2), // 50% -10% translates roughly to this
                    radius: 1.2,
                    colors: [
                      Color(0x0D14120A), // rgba(20,18,10,.05)
                      Color(0x0014120A), // transparent
                    ],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          // The Dialog
          HamsDialog(
            type: type,
            title: title,
            message: message,
            content: content,
            actions: actions,
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}
