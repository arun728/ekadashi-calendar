import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_day_merge.dart';
import '../../models/calendar_entry.dart';

class DayEntriesList extends StatelessWidget {
  final List<DayListItem> items;
  final void Function(DayListItem item)? onTap;
  final void Function(DayListItem item)? onDeleteCustom;

  const DayEntriesList({
    super.key,
    required this.items,
    this.onTap,
    this.onDeleteCustom,
  });

  Color _color(DayItemKind kind) {
    switch (kind) {
      case DayItemKind.ekadashi:
        return const Color(CalendarMarkerColors.ekadashiTeal);
      case DayItemKind.google:
        return const Color(CalendarMarkerColors.googleBlue);
      case DayItemKind.custom:
        return const Color(CalendarMarkerColors.customPurple);
    }
  }

  String _timeLabel(DayListItem item, LanguageService lang) {
    if (item.isAllDay || item.startAt == null) return lang.translate('all_day');
    final fmt = DateFormat.jm(lang.currentLocale.languageCode);
    final start = fmt.format(item.startAt!);
    if (item.endAt == null) return start;
    return '$start – ${fmt.format(item.endAt!)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            lang.translate('no_entries'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final c = _color(item.kind);
        return Dismissible(
          key: Key(item.entryId ?? 'ek_${item.title}_$index'),
          direction: item.editable
              ? DismissDirection.endToStart
              : DismissDirection.none,
          background: Container(
            color: Colors.red.shade700,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: item.editable ? (_) => onDeleteCustom?.call(item) : null,
          child: ListTile(
            leading: Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            title: Text(
              item.title,
              style: TextStyle(fontWeight: FontWeight.w600, color: c),
            ),
            subtitle: Text(
              [
                _timeLabel(item, lang),
                if (item.subtitle != null && item.subtitle!.isNotEmpty)
                  item.subtitle!,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: item.editable
                ? const Icon(Icons.edit_outlined, size: 18)
                : (item.kind == DayItemKind.ekadashi
                      ? const Icon(Icons.chevron_right)
                      : null),
            onTap: () => onTap?.call(item),
          ),
        );
      },
    );
  }
}
