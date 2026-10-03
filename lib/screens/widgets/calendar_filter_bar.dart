import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../models/calendar_entry.dart';
import '../../models/calendar_day_merge.dart';

/// Horizontal chips: All · Ekadashi · Google · Custom (default Ekadashi).
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

  static Color colorFor(CalendarFilter f) {
    switch (f) {
      case CalendarFilter.ekadashi:
        return const Color(CalendarMarkerColors.ekadashiTeal);
      case CalendarFilter.google:
        return const Color(CalendarMarkerColors.googleBlue);
      case CalendarFilter.custom:
        return const Color(CalendarMarkerColors.customPurple);
      case CalendarFilter.all:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: CalendarDayMerge.filterOrder.map((f) {
          final isSelected = selected == f;
          final c = colorFor(f);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(lang.translate(_labels[f]!)),
              selected: isSelected,
              onSelected: (_) => onChanged(f),
              selectedColor: c.withValues(alpha: 0.25),
              checkmarkColor: c,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                color: isSelected ? c : null,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(color: c.withValues(alpha: 0.6)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
