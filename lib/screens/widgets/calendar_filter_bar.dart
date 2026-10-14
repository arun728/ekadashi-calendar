import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../models/calendar_entry.dart';
import '../../models/calendar_day_merge.dart';
import '../../widgets/ios_style.dart';

/// All · Ekadashi · Google · Custom as separate glass chips, each selected
/// in its own colour (CalendarView.swift filterBar). Opens on All.
class CalendarFilterBar extends StatelessWidget {
  final CalendarFilter selected;
  final ValueChanged<CalendarFilter> onChanged;

  const CalendarFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _labels = {
    CalendarFilter.all: 'filter_all',
    CalendarFilter.ekadashi: 'filter_ekadashi',
    CalendarFilter.google: 'filter_google',
    CalendarFilter.custom: 'filter_custom',
  };

  /// The chip colour: teal for All and Ekadashi, Google blue, Custom purple.
  static Color colorFor(CalendarFilter f) => switch (f) {
    CalendarFilter.all || CalendarFilter.ekadashi => IosColors.teal,
    CalendarFilter.google => IosColors.googleBlue,
    CalendarFilter.custom => IosColors.customPurple,
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return SingleChildScrollView(
      key: const Key('calendar_filters_tube'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          for (final f in CalendarDayMerge.filterOrder) ...[
            if (f != CalendarDayMerge.filterOrder.first)
              const SizedBox(width: 8),
            GlassChip(
              key: Key('calendar_filter_${f.name}'),
              label: lang.translate(_labels[f]!),
              color: colorFor(f),
              selected: selected == f,
              onTap: () => onChanged(f),
            ),
          ],
        ],
      ),
    );
  }
}
