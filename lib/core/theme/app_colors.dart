import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds - Sleek obsidian & midnight tones
  static const Color background = Color(0xFF090A0F);
  static const Color surface = Color(0xFF12131D);
  static const Color surfaceLight = Color(0xFF1B1C2A);
  static const Color surfaceElevated = Color(0xFF222436);
  static const Color surfaceGlass = Color(0xCC181926);

  // Borders & Dividers
  static const Color border = Color(0xFF27293D);
  static const Color borderSubtle = Color(0xFF1E2030);
  static const Color borderFocus = Color(0xFFD946EF);

  // Vibrant Accents (Inspired by Reference Image)
  static const Color primary = Color(0xFFD946EF); // Neon Fuchsia / Magenta
  static const Color primaryLight = Color(0xFFF472B6);
  static const Color primaryDark = Color(0xFFC026D3);
  static const Color secondary = Color(0xFF8B5CF6); // Electric Violet
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF43F5E);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF475569);

  // Status indicators
  static const Color statusSubmitted = Color(0xFF6366F1);
  static const Color statusScreening = Color(0xFF06B6D4);
  static const Color statusShortlisted = Color(0xFF8B5CF6);
  static const Color statusInterview = Color(0xFFD946EF);
  static const Color statusOffer = Color(0xFF10B981);
  static const Color statusRejected = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x33D946EF), Color(0x118B5CF6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161724), Color(0xFF11121C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
