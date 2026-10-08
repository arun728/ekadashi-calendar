import 'package:flutter/material.dart';

/// The page background shared with iOS (ios-native Theme.swift
/// AppBackground, docs/ROADMAP.md Phase 8): the scaffold colour with a soft
/// teal gradient from the top left, so the glass surfaces read the same on
/// both platforms.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  static const teal = Color(0xFF00A19B);

  /// #121212 dark, grey 100 light, as the app theme's scaffold colours.
  static Color page(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF121212)
      : const Color(0xFFF5F5F5);

  static LinearGradient gradient(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      teal.withValues(alpha: brightness == Brightness.dark ? .22 : .14),
      Colors.transparent,
      teal.withValues(alpha: .08),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(color: page(brightness)),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient(brightness)),
        child: child,
      ),
    );
  }
}
