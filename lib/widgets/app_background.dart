import 'package:flutter/material.dart';

/// Shared gradient background that reads the current theme's brightness.
///
/// Every screen used to hardcode `colors: [Color(0xFF0A0E1A), Color(0xFF1A1F2E)]`
/// directly in a BoxDecoration, so toggling Dark Mode in Settings changed the
/// saved preference but nothing ever appeared different on screen. Swap that
/// hardcoded Container in each screen's Scaffold body for this widget so the
/// background actually follows the theme.
///
/// Usage:
///   Scaffold(
///     body: AppBackground(
///       child: SafeArea(...),
///     ),
///   )
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0A0E1A), Color(0xFF1A1F2E)]
              : const [Color(0xFFF3F6F3), Color(0xFFE3EEE3)],
        ),
      ),
      child: child,
    );
  }
}