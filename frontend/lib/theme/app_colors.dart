import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════
  // Dark Gradient Background System
  // ═══════════════════════════════════════════
  static const Color backgroundDark = Color(0xFF0F0C29);
  static const Color backgroundMid = Color(0xFF302B63);
  static const Color backgroundLight = Color(0xFF24243E);

  // Glassmorphism Surface
  static const Color glassWhite = Color(0x1AFFFFFF);     // 10% white
  static const Color glassBorder = Color(0x33FFFFFF);     // 20% white
  static const Color glassHighlight = Color(0x0DFFFFFF);  // 5% white

  // Legacy surface (used in some widgets)
  static const Color surface = Color(0xFF1E1B3A);

  // Backgrounds (dark themed)
  static const Color backgroundPrimary = Color(0xFF0F0C29);
  static const Color backgroundSecondary = Color(0xFF1A1640);

  // ═══════════════════════════════════════════
  // Text Colors
  // ═══════════════════════════════════════════
  static const Color textPrimary = Color(0xFFF1F0FF);
  static const Color textSecondary = Color(0x99F1F0FF);   // 60% white-ish

  // ═══════════════════════════════════════════
  // Border
  // ═══════════════════════════════════════════
  static const Color border = Color(0x33FFFFFF);

  // ═══════════════════════════════════════════
  // Accent Colors
  // ═══════════════════════════════════════════
  static const Color primary = Color(0xFF7C6BFF);
  static const Color primarySoft = Color(0x337C6BFF);
  static const Color accent = Color(0xFF00D9FF);
  static const Color accentSoft = Color(0x3300D9FF);

  // ═══════════════════════════════════════════
  // Status Colors
  // ═══════════════════════════════════════════
  static const Color success = Color(0xFF4ADE80);
  static const Color successSoft = Color(0x264ADE80);
  
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningSoft = Color(0x26FBBF24);
  
  static const Color danger = Color(0xFFF87171);
  static const Color dangerSoft = Color(0x26F87171);
  
  static const Color info = Color(0xFF60A5FA);
  static const Color infoSoft = Color(0x2660A5FA);

  // ═══════════════════════════════════════════
  // Gradients
  // ═══════════════════════════════════════════
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundDark, backgroundMid, backgroundLight],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6BFF), Color(0xFF00D9FF)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
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
}
