import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The iOS app's look on Android (ios-native DesignSystem: Theme.swift,
/// Glass.swift, Toast.swift). Every screen uses these so both platforms
/// share colours, glass surfaces, chips, pills, buttons, sheets and toasts.
abstract final class IosColors {
  /// Theme.teal.
  static const teal = Color(0xFF00A19B);

  /// Theme.amber, Theme.partial and Theme.missed.
  static const amber = Color(0xFFFFC208);
  static const partial = Color(0xFFFFA100);
  static const missed = Color(0xFFF0544F);
  static const googleBlue = Color(0xFF4285F4);
  static const customPurple = Color(0xFF9C27B0);

  /// Widget cyan and mist (WidgetViews.swift).
  static const cyan = Color(0xFF00E5FF);

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// SwiftUI .green (Theme.observed), .orange, .red, .gray, .yellow.
  static Color green(BuildContext context) =>
      _dark(context) ? const Color(0xFF30D158) : const Color(0xFF34C759);
  static Color orange(BuildContext context) =>
      _dark(context) ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);
  static Color red(BuildContext context) =>
      _dark(context) ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  static Color gray(BuildContext context) =>
      _dark(context) ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  static Color yellow(BuildContext context) =>
      _dark(context) ? const Color(0xFFFFD60A) : const Color(0xFFFFCC00);

  /// .primary, .secondary, .tertiary text and the list separator.
  static Color primary(BuildContext context) =>
      _dark(context) ? Colors.white : Colors.black;
  static Color secondary(BuildContext context) =>
      _dark(context) ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
  static Color tertiary(BuildContext context) =>
      _dark(context) ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43);
  static Color separator(BuildContext context) =>
      _dark(context) ? const Color(0x99545458) : const Color(0x4A3C3C43);

  /// The grouped-list card (secondarySystemGroupedBackground) and the sheet
  /// background.
  static Color groupedCard(BuildContext context) =>
      _dark(context) ? const Color(0xFF1C1C1E) : Colors.white;
  static Color sheet(BuildContext context) =>
      _dark(context) ? const Color(0xF21C1C1E) : const Color(0xF2F2F2F7);
}

/// SwiftUI text styles (default Dynamic Type sizes).
abstract final class IosText {
  static const largeTitle = 34.0;
  static const title = 28.0;
  static const title2 = 22.0;
  static const title3 = 20.0;
  static const headline = 17.0;
  static const body = 17.0;
  static const callout = 16.0;
  static const subheadline = 15.0;
  static const footnote = 13.0;
  static const caption = 12.0;
  static const caption2 = 11.0;
}

BorderRadius _radius(double r) => BorderRadius.circular(r);

/// A translucent glass panel (Glass.swift glassPanel): blur, the glass
/// gradient, an optional tint and a thin light stroke.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.tint,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final opaque = media.highContrast || media.accessibleNavigation;
    final shape = _radius(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null || onLongPress != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter.grouped(
        enabled: !opaque,
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Color(opaque ? 0xFF2C3232 : 0xB83A4242),
                      Color(opaque ? 0xFF1E2424 : 0x9E222A2A),
                    ]
                  : [
                      Color(opaque ? 0xFFFFFFFF : 0xE6FFFFFF),
                      Color(opaque ? 0xFFF4F7F7 : 0xC7F1F6F5),
                    ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              color: tint?.withValues(alpha: .16),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withValues(
                  alpha: dark ? .14 : .06,
                ),
                width: .7,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A selectable glass capsule (Glass.swift GlassChip): 15 pt, semibold when
/// selected; the selected chip takes [color] for its text, icon and tint.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = IosColors.teal,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? color : IosColors.primary(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GlassPanel(
        radius: 999,
        tint: selected ? color : null,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: IosText.subheadline,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small coloured status pill (Glass.swift StatusPill).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: _radius(999),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: IosText.caption2, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.caption,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Button styles of the iOS app: the prominent teal capsule
/// (primaryActionStyle) and the glass capsule (secondaryActionStyle).
abstract final class IosButtons {
  static ButtonStyle prominent({
    double vertical = 13,
    Color color = IosColors.teal,
  }) => FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    disabledBackgroundColor: color.withValues(alpha: .35),
    disabledForegroundColor: Colors.white70,
    shape: const StadiumBorder(),
    padding: EdgeInsets.symmetric(vertical: vertical, horizontal: 18),
  );

  static ButtonStyle glass(
    BuildContext context, {
    double vertical = 11,
    Color color = IosColors.teal,
  }) => OutlinedButton.styleFrom(
    foregroundColor: color,
    backgroundColor: color.withValues(alpha: .10),
    disabledForegroundColor: IosColors.tertiary(context),
    shape: const StadiumBorder(),
    side: BorderSide(color: color.withValues(alpha: .28), width: .7),
    padding: EdgeInsets.symmetric(vertical: vertical, horizontal: 18),
  );

  /// The label style of both (headline, merged with the button's font).
  static const label = TextStyle(
    fontSize: IosText.headline,
    fontWeight: FontWeight.w600,
  );
}

/// iOS inline navigation title: 17 pt semibold in the primary colour.
TextStyle iosNavTitle(BuildContext context) => TextStyle(
  fontSize: IosText.headline,
  fontWeight: FontWeight.w600,
  color: IosColors.primary(context),
);

/// A teal text button for a navigation or sheet bar ("Cancel", "Done",
/// "Save", "Today"); [bold] for the confirming action.
class BarTextButton extends StatelessWidget {
  const BarTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.bold = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color ?? IosColors.teal,
      disabledForegroundColor: IosColors.tertiary(context),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(48, 44),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: IosText.body,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

/// The bar at the top of a sheet: [leading] (usually Cancel), the inline
/// title and [trailing] (Done/Save), like a SwiftUI sheet's toolbar.
class SheetBar extends StatelessWidget {
  const SheetBar({super.key, required this.title, this.leading, this.trailing});

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: NavigationToolbar(
      leading: leading,
      middle: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: iosNavTitle(context),
        ),
      ),
      trailing: trailing,
      middleSpacing: 8,
    ),
  );
}

/// Presents a sheet the way iOS does: over the tab bar (root navigator),
/// rounded top corners, translucent background, drag to dismiss.
/// [large] fills the screen like the .large detent; otherwise it sizes to
/// its content (.medium) and shows a grabber. [nested] gives the sheet its
/// own navigator, so pages pushed inside stay in the sheet.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool large = true,
  bool nested = false,
  bool grabber = false,
  bool isDismissible = true,
  RouteSettings? routeSettings,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    showDragHandle: false,
    routeSettings: routeSettings,
    backgroundColor: IosColors.sheet(context),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      Widget content = Builder(builder: builder);
      if (nested) {
        content = Navigator(
          onGenerateRoute: (settings) =>
              MaterialPageRoute<void>(settings: settings, builder: builder),
        );
      }
      final body = Column(
        mainAxisSize: large ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (grabber || !large)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: IosColors.tertiary(sheetContext),
                  borderRadius: _radius(3),
                ),
              ),
            ),
          if (large) Expanded(child: content) else Flexible(child: content),
        ],
      );
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: large
            ? FractionallySizedBox(heightFactor: 1, child: body)
            : body,
      );
    },
  );
}

/// The iOS toast (Toast.swift): a glass panel floating above the tab bar,
/// gone after four seconds; [actionLabel] adds a teal action.
void showToast(
  BuildContext context,
  String text, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _ToastHost.current?.dismiss();
  late final OverlayEntry entry;
  final key = GlobalKey<_ToastViewState>();
  entry = OverlayEntry(
    builder: (_) => _ToastView(
      key: key,
      text: text,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (_ToastHost.current?.entry == entry) _ToastHost.current = null;
      },
    ),
  );
  _ToastHost.current = _ToastHost(entry, key);
  overlay.insert(entry);
}

class _ToastHost {
  _ToastHost(this.entry, this.key);
  final OverlayEntry entry;
  final GlobalKey<_ToastViewState> key;
  static _ToastHost? current;

  void dismiss() {
    key.currentState?.close();
    if (key.currentState == null && entry.mounted) entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.text,
    required this.duration,
    required this.onDone,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, close);
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: 96 + media.padding.bottom,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .4),
            end: Offset.zero,
          ).animate(curve),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(
              key: const Key('app_toast'),
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: IosText.subheadline,
                        color: IosColors.primary(context),
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        close();
                        widget.onAction?.call();
                      },
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(
                          fontSize: IosText.subheadline,
                          fontWeight: FontWeight.w600,
                          color: IosColors.teal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An iOS "ContentUnavailableView": a large symbol, a bold title, an
/// optional description and action.
class UnavailableView extends StatelessWidget {
  const UnavailableView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: IosColors.secondary(context)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.title3,
              fontWeight: FontWeight.w700,
              color: IosColors.primary(context),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: IosText.subheadline,
                color: IosColors.secondary(context),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
