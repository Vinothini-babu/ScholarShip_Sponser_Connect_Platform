import 'package:flutter/material.dart';

/// "Bridge" palette — connects students & sponsors.
/// Field names kept identical to your original file so nothing
/// else in the app needs to change — only the values shifted.
class AppColors {
  // Was #2563EB (generic SaaS blue) -> Ink Navy: institutional, trustworthy
  static const Color primary = Color(0xFF1B2A4A);

  // Was #3B82F6 -> Warm Gold: scholarships = opportunity/value
  static const Color secondary = Color(0xFFD4A63A);

  // Was #F8FAFC (cold white) -> Paper White: warmer, less clinical
  static const Color background = Color(0xFFF7F6F2);

  static const Color white = Colors.white;

  // Kept close to original for readability, slightly warmed
  static const Color textPrimary = Color(0xFF1B2A4A);
  static const Color textSecondary = Color(0xFF5C6470);

  // Was #22C55E -> Soft Sage: calmer approval/success color
  static const Color success = Color(0xFF7A9B76);

  // Kept as amber, works fine with the new palette
  static const Color warning = Color(0xFFD4A63A);

  // Was #EF4444 -> Coral: slightly warmer, less alarm-red
  static const Color error = Color(0xFFE4633F);

  static const Color card = Colors.white;
}
