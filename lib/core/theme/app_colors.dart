import 'package:flutter/material.dart';

/// AttendHub brand colour palette.
///
/// Sky-blue primary + emerald accent on a light sky-50 surface.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Primary – Sky blue
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF0284C7); // sky-600
  static const Color primaryLight = Color(0xFF0EA5E9); // sky-500
  static const Color primaryDark = Color(0xFF075985); // sky-800
  static const Color primaryContainer = Color(0xFFE0F2FE); // sky-100

  // ---------------------------------------------------------------------------
  // Accent – Emerald green (used for scanner, success states)
  // ---------------------------------------------------------------------------
  static const Color accent = Color(0xFF10B981); // emerald-500
  static const Color accentDark = Color(0xFF059669); // emerald-600
  static const Color accentContainer = Color(0xFFD1FAE5); // emerald-100

  // ---------------------------------------------------------------------------
  // Surfaces & backgrounds
  // ---------------------------------------------------------------------------
  static const Color surface = Color(0xFFF0F9FF); // sky-50
  static const Color background = Color(0xFFF8FAFC); // slate-50
  static const Color card = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0); // slate-200

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1E293B); // slate-800
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textMuted = Color(0xFF94A3B8); // slate-400

  // ---------------------------------------------------------------------------
  // Status colours
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);

  // ---------------------------------------------------------------------------
  // Scanner laser line (animated emerald glow)
  // ---------------------------------------------------------------------------
  static const Color laserLine = Color(0xFF10B981);
  static const Color laserGlow = Color(0x6610B981);

  // ---------------------------------------------------------------------------
  // Neutral
  // ---------------------------------------------------------------------------
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shimmer = Color(0xFFF1F5F9);
}
