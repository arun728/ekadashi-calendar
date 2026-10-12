import 'package:flutter/material.dart';

import 'ios_style.dart';

/// A screen's sub-sections as a row of glass chips (Panchang and Journey,
/// docs/ROADMAP.md Phase 9). The pages below also change with a swipe; the
/// row keeps the selected chip in view.
class SectionChipBar extends StatelessWidget {
  const SectionChipBar({
    super.key,
    required this.labels,
    required this.chipKeys,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final List<Key> chipKeys;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Separate glass capsules in a scrolling row, like iOS SectionChips
  /// (Glass.swift): spacing 8, padding 16/8.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          SelectedChipAnchor(
            selected: i == selected,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: GlassChip(
                key: chipKeys[i],
                label: labels[i],
                selected: i == selected,
                onTap: () => onSelected(i),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Scrolls its chip into the middle of a horizontal chip row when it
/// becomes selected (a swipe can select a chip that is out of view).
class SelectedChipAnchor extends StatefulWidget {
  const SelectedChipAnchor({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  State<SelectedChipAnchor> createState() => _SelectedChipAnchorState();
}

class _SelectedChipAnchorState extends State<SelectedChipAnchor> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _reveal(Duration.zero);
  }

  @override
  void didUpdateWidget(SelectedChipAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _reveal(const Duration(milliseconds: 250));
    }
  }

  void _reveal(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: .5,
        duration: duration,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Moves [controller] to [page] the way a tab bar does: next door with an
/// animation, further away by jumping beside it first.
void showSectionPage(PageController controller, int page) {
  if (!controller.hasClients) return;
  final current = controller.page?.round() ?? page;
  if ((page - current).abs() > 1) {
    controller.jumpToPage(page > current ? page - 1 : page + 1);
  }
  controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
}
