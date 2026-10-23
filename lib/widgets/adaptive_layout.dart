import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One pane (phones, a foldable's outer screen) or two side by side (a
/// foldable's inner screen, tablets, the iPhone Duo's inner screen).
enum PaneLayout {
  single,
  sideBySide;

  int get columns => this == sideBySide ? 2 : 1;
  bool get isSideBySide => this == sideBySide;
}

/// The width rule both apps follow on wide screens (docs/FOLDABLES.md;
/// test/fixtures/adaptive_layout.json, AdaptiveLayout in EkadashiCore).
/// Widths are the logical pixels the app's content is given, after the
/// side system insets: never the device or its orientation.
abstract final class AdaptiveLayout {
  /// Content this wide or wider shows two panes. Every phone in portrait
  /// and a foldable's outer screen are narrower; its inner screen is wider.
  static const double twoPaneMinWidth = 560;

  /// Single-column content (Settings, details) stops growing here.
  static const double readableMaxWidth = 720;
  static const double paneSpacing = 16;

  static PaneLayout panes(double width) =>
      width >= twoPaneMinWidth ? PaneLayout.sideBySide : PaneLayout.single;

  /// The width readable content takes; 0 until the width is known.
  static double readableWidth(double width) =>
      width > 0 ? math.min(width, readableMaxWidth) : 0;

  /// The margin on each side that centres the readable width.
  static double sideMargin(double width) =>
      width.isFinite && width > 0 ? (width - readableWidth(width)) / 2 : 0;

  /// The side padding of a list padded by [base] on phones: on wide screens
  /// it grows so the content stays at the readable width, centred (as
  /// .readableListMargins() on iOS).
  static double readableInset(double width, double base) =>
      base + sideMargin(width - 2 * base);

  /// The app's width (the window, after the side system insets), as iOS
  /// measures each tab. Unfolding or rotating rebuilds the callers.
  static double widthOf(BuildContext context) {
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) return 0;
    final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    return size.width - padding.left - padding.right;
  }

  static PaneLayout of(BuildContext context) => panes(widthOf(context));
}

/// Two panes: side by side on wide screens (top aligned, equal widths),
/// stacked on phones in the same order. Each pane keeps its state when a
/// fold or rotation switches the layout (as AnyLayout on iOS).
///
/// With [fill] the panes share a bounded height: side by side both take it,
/// stacked the leading pane takes what the trailing one leaves.
class AdaptivePanes extends StatefulWidget {
  const AdaptivePanes({
    super.key,
    required this.leading,
    this.trailing,
    this.spacing = AdaptiveLayout.paneSpacing,
    this.stackedSpacing = 12,
    this.fill = false,
  });

  final Widget leading;

  /// Left out, the leading pane is shown alone.
  final Widget? trailing;
  final double spacing;

  /// The stacked spacing; phones keep each screen's own.
  final double stackedSpacing;
  final bool fill;

  @override
  State<AdaptivePanes> createState() => _AdaptivePanesState();
}

class _AdaptivePanesState extends State<AdaptivePanes> {
  final _leadingKey = GlobalKey();
  final _trailingKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final leading = KeyedSubtree(key: _leadingKey, child: widget.leading);
    final trailing = widget.trailing == null
        ? null
        : KeyedSubtree(key: _trailingKey, child: widget.trailing!);
    if (AdaptiveLayout.of(context).isSideBySide) {
      return Row(
        crossAxisAlignment: widget.fill
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          Expanded(child: leading),
          if (trailing != null) ...[
            SizedBox(width: widget.spacing),
            Expanded(child: trailing),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.fill) Expanded(child: leading) else leading,
        if (trailing != null) ...[
          SizedBox(height: widget.stackedSpacing),
          trailing,
        ],
      ],
    );
  }
}

/// Single-column content stops at the readable width, centred.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: alignment,
      child: SizedBox(
        width: AdaptiveLayout.readableWidth(constraints.maxWidth),
        child: child,
      ),
    ),
  );
}

/// A list that becomes rows of [AdaptiveLayout.of] columns on wide screens
/// (LazyVGrid on iOS): each row as tall as its tallest cell, top aligned.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = AdaptiveLayout.of(context).columns;
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        columns == 1
            ? children[start]
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: start + c < children.length
                          ? children[start + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}
