import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Opt-in app appearance. An absent scope preserves the existing renderer,
/// including isolated widgets, native widget previews and exported share cards.
class GlassLook extends InheritedWidget {
  const GlassLook({super.key, required this.enabled, required super.child});
  final bool enabled;
  static bool active(BuildContext context) {
    final enabled =
        context.dependOnInheritedWidgetOfExactType<GlassLook>()?.enabled ??
        false;
    final media = MediaQuery.maybeOf(context);
    return enabled &&
        !(media?.highContrast ?? false) &&
        !(media?.accessibleNavigation ?? false);
  }

  @override
  bool updateShouldNotify(GlassLook oldWidget) => enabled != oldWidget.enabled;
}

/// Clearer surfaces matching the restrained fills and highlights of iOS On.
/// The clip bounds every blur; text opacity and layout remain independent.
class ClearGlassSurface extends StatelessWidget {
  const ClearGlassSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.tint,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: .018),
                      Colors.black.withValues(alpha: .06),
                    ]
                  : [
                      Colors.white.withValues(alpha: .24),
                      Colors.white.withValues(alpha: .12),
                    ],
            ),
            color: tint?.withValues(alpha: .08),
            border: Border.all(
              width: .75,
              color: Colors.white.withValues(alpha: dark ? .18 : .7),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
