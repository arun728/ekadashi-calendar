import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_tube.dart';

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length);
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const accent = GlassTubeColors.teal;
    final foreground = GlassTubeColors.foreground(context);
    final scale = media.textScaler.scale(11.5) / 11.5;
    final height = math.max(76.0, 46 + 28 * scale);
    final duration = media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return SafeArea(
      key: const Key('glass_navigation_bar'),
      top: false,
      child: Padding(
        // Six destinations need 288dp of touch area plus the tube's padding.
        padding: EdgeInsets.fromLTRB(
          media.size.width < 340 ? 10 : 12,
          6,
          media.size.width < 340 ? 10 : 12,
          12,
        ),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GlassTube(
              optionCount: items.length,
              radius: 44,
              shadow: true,
              surfaceKey: const Key('glass_capsule_surface'),
              child: SizedBox(
                height: height - 10,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedAlign(
                        alignment: Alignment(
                          -1 + currentIndex * 2 / (items.length - 1),
                          0,
                        ),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        child: FractionallySizedBox(
                          widthFactor: 1 / items.length,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(38),
                              color: GlassTubeColors.selection,
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
                            hint: MaterialLocalizations.of(context).tabLabel(
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
    );
  }
}
