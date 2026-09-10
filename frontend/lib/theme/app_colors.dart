import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════
  // English Light Background System
  // ═══════════════════════════════════════════
  static const Color backgroundLight = Color(0xFFF9FAFB); // Cool off-white
  static const Color backgroundMid = Color(0xFFF3F4F6); // Very subtle gray
  static const Color backgroundDark = Color(0xFFE5E7EB); // Deeper gray for contrast

  // Premium Surface (Cards, Dialogs)
  static const Color surface = Color(0xFFFFFFFF); // Pure white for cards
  static const Color surfaceHighlight = Color(0xFFF8FAFC); // Slight tint for hovered/active elements

  // Backgrounds (used primarily for Scaffold and Elevanted backgrounds)
  static const Color backgroundPrimary = Color(0xFFF9FAFB); 
  static const Color backgroundSecondary = Color(0xFFFFFFFF);

  // ═══════════════════════════════════════════
  // Text Colors (Slate / Charcoal)
  // ═══════════════════════════════════════════
  static const Color textPrimary = Color(0xFF0F172A); // Very dark slate (near black)
  static const Color textSecondary = Color(0xFF475569); // Muted slate gray

  // ═══════════════════════════════════════════
  // Borders
  // ═══════════════════════════════════════════
  static const Color border = Color(0xFFE2E8F0); // Very light crisp border

  // ═══════════════════════════════════════════
  // Accent Colors (Royal / English Navy)
  // ═══════════════════════════════════════════
  static const Color primary = Color(0xFF1E3A8A); // Deep English Navy
  static const Color primarySoft = Color(0x331E3A8A);
  static const Color accent = Color(0xFF2563EB); // Royal Blue
  static const Color accentSoft = Color(0x332563EB);

  // ═══════════════════════════════════════════
  // Status Colors (Refined & elegant)
  // ═══════════════════════════════════════════
  static const Color success = Color(0xFF059669); // Emerald Green
  static const Color successSoft = Color(0x26059669);
  
  static const Color warning = Color(0xFFD97706); // Amber/Bronze
  static const Color warningSoft = Color(0x26D97706);
  
  static const Color danger = Color(0xFFDC2626); // Classic Red
  static const Color dangerSoft = Color(0x26DC2626);
  
  static const Color info = Color(0xFF0284C7); // Light Blue
  static const Color infoSoft = Color(0x260284C7);

  // ═══════════════════════════════════════════
  // Gradients (Subtle and elegant)
  // ═══════════════════════════════════════════
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundLight, backgroundMid, backgroundDark],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
  );

  // ═══════════════════════════════════════════
  // Legacy Aliases (To fix compilation errors)
  // ═══════════════════════════════════════════
  static const Color bg = backgroundPrimary;
  static const Color bgElevated = backgroundSecondary;
  static const Color text = textPrimary;
  static const Color textMuted = textSecondary;
  static const Color borderSoft = border;

  static const Color green = success;
  static const Color greenSoft = successSoft;
  static const Color amber = warning;
  static const Color amberSoft = warningSoft;
  static const Color red = danger;
  static const Color redSoft = dangerSoft;
  static const Color teal = info;
  static const Color tealSoft = infoSoft;

  static const LinearGradient accentGradient = primaryGradient;
  
  // Kept for backward compatibility with components using these specific names
  static const Color glassWhite = Color(0xFFFFFFFF); 
  static const Color glassBorder = Color(0xFFE2E8F0);
  static const Color glassHighlight = Color(0xFFF8FAFC);
}

