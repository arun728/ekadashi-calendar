import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_language.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/ekadashi_service.dart';
import '../../services/language_service.dart';
import '../../services/vrat_tracker_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/ios_style.dart';
import '../vrat_tracker/record_vrat_dialog.dart' show vratStatusColor;

/// The year's Ekadashis beside Home's card on wide screens
/// (docs/FOLDABLES.md, HomeEkadashiList in TodayView.swift): the card's
/// Ekadashi is highlighted and a tap opens another's card.
class HomeEkadashiList extends StatefulWidget {
  const HomeEkadashiList({
    super.key,
    required this.ekadashis,
    required this.selected,
    required this.year,
    required this.today,
    required this.onSelect,
  });

  final List<EkadashiDate> ekadashis;
  final int selected;
  final int year;
  final DateTime today;
  final ValueChanged<int> onSelect;

  @override
  State<HomeEkadashiList> createState() => _HomeEkadashiListState();
}

class _HomeEkadashiListState extends State<HomeEkadashiList> {
  final _rows = <int, GlobalKey>{};

  GlobalKey _row(int index) => _rows.putIfAbsent(index, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _revealSelected(animated: false);
  }

  @override
  void didUpdateWidget(HomeEkadashiList old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _revealSelected(animated: true);
  }

  /// Keeps the card's Ekadashi in view, centred.
  void _revealSelected({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _rows[widget.selected]?.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: .5,
        duration: animated ? const Duration(milliseconds: 300) : Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final language = lang.currentLocale.languageCode;
    final tracker = context.watch<VratTrackerService?>();
    final today = DateUtils.dateOnly(widget.today);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${widget.year} ${lang.translate('ekadashis_unit')}',
              style: const TextStyle(
                fontSize: IosText.headline,
                fontWeight: FontWeight.w600,
                color: IosColors.teal,
              ),
            ),
          ),
          for (var i = 0; i < widget.ekadashis.length; i++) ...[
            const SizedBox(height: 8),
            _rowFor(
              i,
              widget.ekadashis[i],
              language,
              tracker,
              passed: DateUtils.dateOnly(
                widget.ekadashis[i].date,
              ).isBefore(today),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowFor(
    int index,
    EkadashiDate ekadashi,
    String language,
    VratTrackerService? tracker, {
    required bool passed,
  }) {
    final selected = index == widget.selected;
    final status = tracker != null && tracker.trackerEnabled
        ? tracker.getRecordByUid(ekadashi.occurrenceUid)?.status
        : null;
    final IconData? icon = switch (status) {
      ObservanceStatus.observed => AppIcons.statusObserved,
      ObservanceStatus.partial => AppIcons.statusPartial,
      ObservanceStatus.missed => AppIcons.statusMissed,
      ObservanceStatus.unrecorded => AppIcons.statusUnrecorded,
      null => null,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Opacity(
        opacity: passed && !selected ? .6 : 1,
        child: DecoratedBox(
          key: _row(index),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? IosColors.teal : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: GlassPanel(
            key: Key('home_list_row_$index'),
            radius: 14,
            tint: selected ? IosColors.teal : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () => widget.onSelect(index),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ekadashi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: IosText.subheadline,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? IosColors.teal
                              : IosColors.primary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.fullDate(ekadashi.date, language),
                        style: TextStyle(
                          fontSize: IosText.caption,
                          color: IosColors.secondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: vratStatusColor(context, status)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
