import 'dart:ui' as ui;
import 'package:flutter/material.dart';

abstract final class GlassTubeColors {
  static const teal = Color(0xFF00A19B);
  static const selection = Colors.black;
  static Color optionSelection(BuildContext context) => teal.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .12,
  );
  static Color foreground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF263A3A);
}

/// A shared clipped glass enclosure for two or more related controls.
/// Callers retain their original controls, callbacks and accessibility roles.
class GlassTube extends StatelessWidget {
  const GlassTube({
    super.key,
    required this.optionCount,
    required this.child,
    this.padding = const EdgeInsets.all(5),
    this.radius = 28,
    this.shadow = false,
    this.surfaceKey,
  }) : assert(optionCount >= 2);
  final int optionCount;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = media.highContrast || media.accessibleNavigation;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .28 : .12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        key: surfaceKey,
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          enabled: !opaque,
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Color(opaque ? 0xFF303A3A : 0xCC465050),
                        Color(opaque ? 0xFF1E2828 : 0xB3222C2C),
                      ]
                    : [
                        Color(opaque ? 0xFFFFFFFF : 0xECFFFFFF),
                        Color(opaque ? 0xFFF1F6F5 : 0xCDE4F0ED),
                      ],
              ),
              border: Border.all(
                color: GlassTubeColors.foreground(
                  context,
                ).withValues(alpha: opaque ? .4 : .2),
              ),
            ),
            // RawChip creates a canvas Material even with a transparent background.
            // Keep that canvas transparent so the shared glass remains visible.
            child: Theme(
              data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassFilterChip extends StatelessWidget {
  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    this.showCheckmark = true,
  });
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final bool showCheckmark;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: label,
    selected: selected,
    onSelected: onSelected,
    avatar: avatar,
    showCheckmark: showCheckmark,
    checkmarkColor: GlassTubeColors.teal,
    selectedColor: GlassTubeColors.optionSelection(context),
    backgroundColor: Colors.transparent,
    side: BorderSide.none,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected
          ? GlassTubeColors.teal
          : GlassTubeColors.foreground(context),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Leaves a lone action ungrouped when its optional sibling is unavailable.
class GlassOptionGroup extends StatelessWidget {
  const GlassOptionGroup({
    super.key,
    required this.optionCount,
    required this.child,
  });
  final int optionCount;
  final Widget child;
  @override
  Widget build(BuildContext context) => optionCount >= 2
      ? GlassTube(optionCount: optionCount, child: child)
      : child;
}
