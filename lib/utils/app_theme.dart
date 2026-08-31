import 'package:flutter/material.dart';

/// Theme-aware colors used across the app.
/// Prefer these (or Theme.of(context)) over hardcoded dark-only colors.
class AppThemeColors {
  AppThemeColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primary body / title text
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF1A1F1A);

  /// Secondary / muted text
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? Colors.grey[400]! : Colors.grey[700]!;

  /// Hint / disabled text
  static Color textHint(BuildContext context) =>
      isDark(context) ? Colors.grey[600]! : Colors.grey[500]!;

  /// Page gradient (top → bottom)
  static List<Color> pageGradient(BuildContext context) => isDark(context)
      ? const [Color(0xFF0A0E1A), Color(0xFF1A1F2E), Color(0xFF0D1B2A)]
      : const [Color(0xFFF3F6F3), Color(0xFFE8F0E8), Color(0xFFDCE8DC)];

  static List<Color> pageGradientSimple(BuildContext context) =>
      isDark(context)
          ? const [Color(0xFF0A0E1A), Color(0xFF1A1F2E)]
          : const [Color(0xFFF3F6F3), Color(0xFFE3EEE3)];

  /// Card / section fill
  static List<Color> cardGradient(BuildContext context) => isDark(context)
      ? [
          Colors.green[900]!.withOpacity(0.35),
          Colors.green[800]!.withOpacity(0.12),
        ]
      : [
          Colors.green[100]!.withOpacity(0.9),
          Colors.green[50]!.withOpacity(0.7),
        ];

  static Color cardBorder(BuildContext context) => isDark(context)
      ? Colors.green[700]!.withOpacity(0.35)
      : Colors.green[300]!.withOpacity(0.8);

  /// Solid surface (dialogs, dropdowns, bottom sheets)
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1F2E) : Colors.white;

  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? const Color(0xFF243040) : const Color(0xFFF5F8F5);

  /// Bottom navigation bar
  static List<Color> bottomNavGradient(BuildContext context) => isDark(context)
      ? const [Color(0xFF1A1F2E), Color(0xFF0A0E1A)]
      : const [Color(0xFFFFFFFF), Color(0xFFF0F4F0)];

  static Color bottomNavSelected(BuildContext context) =>
      isDark(context) ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

  static Color bottomNavUnselected(BuildContext context) =>
      isDark(context) ? Colors.grey[600]! : Colors.grey[600]!;

  /// Input fills
  static Color inputFill(BuildContext context) => isDark(context)
      ? Colors.grey[800]!.withOpacity(0.4)
      : Colors.grey[200]!;

  static Color divider(BuildContext context) => isDark(context)
      ? Colors.grey[800]!.withOpacity(0.5)
      : Colors.grey[300]!;

  static Color icon(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF1A1F1A);

  static Color iconMuted(BuildContext context) =>
      isDark(context) ? Colors.grey : Colors.grey[700]!;

  /// Soft green panel fill (replaces Colors.green[900]!.withOpacity(...))
  static Color panelFill(BuildContext context, [double darkOpacity = 0.2]) =>
      isDark(context)
          ? Colors.green[900]!.withOpacity(darkOpacity)
          : Colors.green[50]!;

  static Color panelFillStrong(BuildContext context) => isDark(context)
      ? Colors.green[900]!.withOpacity(0.3)
      : Colors.green[100]!;
}
