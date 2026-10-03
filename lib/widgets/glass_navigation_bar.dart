import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Android glass-inspired navigation. One clipped backdrop keeps blur work
/// bounded; accessibility can request an opaque, still fully operable surface.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(items.length == 5),
       assert(currentIndex >= 0 && currentIndex < 5);

  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = media.highContrast || media.accessibleNavigation;
    final accent = dark ? const Color(0xFF57DED2) : const Color(0xFF006B64);
    final foreground = dark ? Colors.white : const Color(0xFF263A3A);
    final scale = media.textScaler.scale(11.5) / 11.5;
    final height = math.max(76.0, 46 + 28 * scale);
    final radius = BorderRadius.circular(44);
    final duration = media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return SafeArea(
      key: const Key('glass_navigation_bar'),
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? .28 : .12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                key: const Key('glass_capsule_surface'),
                borderRadius: radius,
                child: BackdropFilter(
                  enabled: !opaque,
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: radius,
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
                        color: foreground.withValues(alpha: opaque ? .4 : .2),
                      ),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedAlign(
                            alignment: Alignment(-1 + currentIndex * .5, 0),
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            child: FractionallySizedBox(
                              widthFactor: 1 / items.length,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(38),
                                  color: accent.withValues(
                                    alpha: dark ? .15 : .12,
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: .22),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(items.length, (index) {
                            final selected = index == currentIndex;
                            final item = items[index];
                            final label = item.label ?? '';
                            return Expanded(
                              child: Semantics(
                                key: Key('glass_tab_$index'),
                                container: true,
                                label: label,
                                hint: MaterialLocalizations.of(context)
                                    .tabLabel(
                                      tabIndex: index + 1,
                                      tabCount: items.length,
                                    ),
                                button: true,
                                selected: selected,
                                onTap: () => onTap(index),
                                excludeSemantics: true,
                                child: Tooltip(
                                  message: label,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(38),
                                      excludeFromSemantics: true,
                                      onTap: () => onTap(index),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconTheme(
                                              data: IconThemeData(
                                                size: 25,
                                                color: selected
                                                    ? accent
                                                    : foreground,
                                              ),
                                              child: selected
                                                  ? item.activeIcon
                                                  : item.icon,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                height: 1.15,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? accent
                                                    : foreground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
