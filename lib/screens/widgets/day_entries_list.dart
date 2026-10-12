import 'package:provider/provider.dart';
import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../models/calendar_day_merge.dart';
import '../../widgets/ios_style.dart';

/// Google and custom entries of one day as glass cards
/// (CalendarView.swift DayEntriesList). Custom entries open the editor on a
/// tap and offer Edit and Delete Record on a long press.
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

  Color _color(DayItemKind kind) => switch (kind) {
    DayItemKind.ekadashi => IosColors.teal,
    DayItemKind.google => IosColors.googleBlue,
    DayItemKind.custom => IosColors.customPurple,
  };

  String _timeLabel(DayListItem item, LanguageService lang) {
    if (item.isAllDay || item.startAt == null) return lang.translate('all_day');
    final language = lang.currentLocale.languageCode;
    String fmt(DateTime t) => AppStrings.clock(t.hour, t.minute, language);
    final start = fmt(item.startAt!);
    if (item.endAt == null) return start;
    return '$start – ${fmt(item.endAt!)}';
  }

  /// The iOS context menu: Edit and a red Delete Record.
  Future<void> _menu(
    BuildContext context,
    DayListItem item,
    LanguageService lang,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(
              context,
              rootNavigator: true,
            ).overlay?.context.findRenderObject()
            as RenderBox?;
    if (box == null || overlay == null) return;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final red = IosColors.red(context);
    final primary = IosColors.primary(context);
    final choice = await showMenu<String>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: IosColors.groupedCard(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem(
          key: const Key('calendar_entry_edit'),
          value: 'edit',
          child: _MenuRow(
            label: lang.translate('edit_entry'),
            icon: Icons.edit_outlined,
            color: primary,
          ),
        ),
        PopupMenuItem(
          key: const Key('calendar_entry_delete'),
          value: 'delete',
          child: _MenuRow(
            label: lang.translate('delete_record'),
            icon: Icons.delete_outline,
            color: red,
          ),
        ),
      ],
    );
    if (choice == 'edit') onTap?.call(item);
    if (choice == 'delete') onDeleteCustom?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    if (items.isEmpty) {
      // Grey and centred with padding, as on the iPhone.
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          lang.translate('no_entries'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: IosText.subheadline,
            color: IosColors.secondary(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _row(context, item, lang),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, DayListItem item, LanguageService lang) {
    final color = _color(item.kind);
    final subtitle = [
      _timeLabel(item, lang),
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
    ].join(' · ');
    return Builder(
      builder: (rowContext) => GlassPanel(
        key: Key('calendar_entry_${item.entryId ?? item.title}'),
        radius: 14,
        padding: const EdgeInsets.all(12),
        onTap: item.editable ? () => onTap?.call(item) : null,
        onLongPress: item.editable ? () => _menu(rowContext, item, lang) : null,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: IosText.subheadline,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: IosText.caption,
                      color: IosColors.secondary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (item.editable) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.edit_outlined,
                size: IosText.footnote + 2,
                color: IosColors.secondary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: IosText.body, color: color),
        ),
      ),
      const SizedBox(width: 16),
      Icon(icon, size: 20, color: color),
    ],
  );
}
