import 'package:flutter/material.dart';
import 'glass_tube.dart';

/// Keep the daily devotion controls consistent with the existing teal navigation.
class DevotionTheme extends StatelessWidget {
  const DevotionTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: GlassTubeColors.teal,
          onPrimary: Colors.white,
          secondary: GlassTubeColors.teal,
          onSecondary: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      child: child,
    );
  }
}
