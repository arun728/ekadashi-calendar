import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_language.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/achievement_evaluator.dart';
import '../../services/ekadashi_service.dart';
import '../../services/language_service.dart';
import '../../services/premium_service.dart';
import '../../services/vrat_recording.dart';
import '../../services/vrat_statistics_service.dart';
import '../../services/vrat_tracker_service.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/ios_style.dart';
import '../../widgets/section_pager.dart';
import '../premium_screen.dart';
import 'achievement_unlock_dialog.dart';
import 'record_vrat_dialog.dart';
import '../../widgets/app_icons.dart';

/// The Journey (Vrat) tab: Overview, History, Statistics and Achievements
/// (iOS VratView). Recording, history, streaks and statistics are free;
/// three entries and three badges are free, more need Premium.
class VratTrackerScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;
  final String currentTimezone;

  const VratTrackerScreen({
    super.key,
    required this.ekadashiList,
    required this.currentTimezone,
  });

  @override
  State<VratTrackerScreen> createState() => _VratTrackerScreenState();
}

/// Journey's sections; each name is also its label key.
enum _JourneySection { overview, history, statistics, achievements }

class _VratTrackerScreenState extends State<VratTrackerScreen> {
  static const teal = IosColors.teal;

  final _pages = PageController();
  var _section = _JourneySection.overview;
  int _selectedYear = DateTime.now().year;
  ObservanceStatus? _historyStatusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tracker = Provider.of<VratTrackerService>(context, listen: false);
      if (!tracker.isInitialized) {
        tracker.init(occurrences: widget.ekadashiList);
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final tracker = Provider.of<VratTrackerService>(context);

    if (tracker.storageError != null) {
      // iOS ContentUnavailableView with a prominent retry.
      return Material(
        type: MaterialType.transparency,
        child: UnavailableView(
          icon: AppIcons.journeyStorageFailed,
          title: lang.translate('tracker_storage_failed'),
          description: tracker.storageError,
          action: FilledButton(
            onPressed: () => tracker.init(occurrences: widget.ekadashiList),
            style: IosButtons.prominent(),
            child: Text(lang.translate('retry'), style: IosButtons.label),
          ),
        ),
      );
    }

    // The sections are glass chips, as in Panchang, and also change with a
    // horizontal swipe.
    const sections = _JourneySection.values;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          SectionChipBar(
            key: const Key('vrat_tabs_tube'),
            labels: [for (final s in sections) lang.translate(s.name)],
            chipKeys: [for (final s in sections) Key('journey_tab_${s.name}')],
            selected: _section.index,
            onSelected: (index) {
              setState(() => _section = sections[index]);
              showSectionPage(_pages, index);
            },
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: sections.length,
              onPageChanged: (index) =>
                  setState(() => _section = sections[index]),
              itemBuilder: (_, index) => KeyedSubtree(
                key: ValueKey(sections[index]),
                child: switch (sections[index]) {
                  _JourneySection.overview => _buildOverviewTab(lang, tracker),
                  _JourneySection.history => _buildHistoryTab(lang, tracker),
                  _JourneySection.statistics => _buildStatisticsTab(
                    lang,
                    tracker,
                  ),
                  _JourneySection.achievements => _buildAchievementsTab(
                    lang,
                    tracker,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom padding so the last item clears the floating tab bar.
  static const _bottomInset = 100.0;

  List<int> _years(VratTrackerService tracker) =>
      VratStatisticsService.getAvailableYears(
        occurrences: widget.ekadashiList,
        history: tracker.getAllRecords(),
      );

  int _coherentSelectedYear(List<int> availableYears) {
    if (availableYears.contains(_selectedYear)) return _selectedYear;
    if (availableYears.contains(DateTime.now().year)) {
      return DateTime.now().year;
    }
    return availableYears.first;
  }

  TextStyle _secondary(double size) =>
      TextStyle(fontSize: size, color: IosColors.secondary(context));

  // ==================== OVERVIEW ====================
  Widget _buildOverviewTab(LanguageService lang, VratTrackerService tracker) {
    final currentStreak = tracker.getCurrentStreak(widget.ekadashiList);
    final longestStreak = tracker.getLongestStreak(widget.ekadashiList);
    final selectedYear = _coherentSelectedYear(_years(tracker));
    final yearStats = tracker.getAnnualStats(
      year: selectedYear,
      occurrences: widget.ekadashiList,
    );
    final totalObserved = tracker
        .getAllRecords()
        .where((h) => h.status == ObservanceStatus.observed)
        .length;
    final nextMilestone = AchievementEvaluator.getNextMilestone(
      userAchievements: tracker.userAchievements,
      totalObserved: totalObserved,
      longestStreak: longestStreak,
    );
    final unit = lang.translate('ekadashis_unit');

    // Wide screens show the metrics beside the recent Ekadashis.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomInset),
      children: [
        AdaptivePanes(
          stackedSpacing: 20,
          leading: Column(
            key: const Key('journey_overview_metrics_pane'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pair(
                key: const Key('journey_overview_streaks'),
                _MetricCard(
                  panelKey: const Key('journey_metric_current_streak'),
                  title: lang.translate('current_streak'),
                  value: '$currentStreak',
                  subtitle: unit,
                  icon: AppIcons.journeyStreak,
                  color: IosColors.orange(context),
                ),
                _MetricCard(
                  panelKey: const Key('journey_metric_longest_streak'),
                  title: lang.translate('longest_streak'),
                  value: '$longestStreak',
                  subtitle: unit,
                  icon: AppIcons.journeyBest,
                  color: IosColors.amber,
                ),
              ),
              const SizedBox(height: 12),
              _pair(
                _MetricCard(
                  panelKey: const Key('journey_metric_annual_completion'),
                  title: '$selectedYear ${lang.translate('annual_completion')}',
                  value: '${yearStats.completionPercentage.round()}%',
                  subtitle:
                      '${yearStats.observedCount} / ${yearStats.totalOccurrences}',
                  icon: AppIcons.journeyRate,
                  color: teal,
                ),
                _MetricCard(
                  panelKey: const Key('journey_metric_total_observed'),
                  title: lang.translate('total_observed'),
                  value: '$totalObserved',
                  subtitle: unit,
                  icon: AppIcons.journeyObserved,
                  color: IosColors.green(context),
                ),
              ),
              if (nextMilestone != null) ...[
                const SizedBox(height: 20),
                _buildNextMilestoneCard(lang, nextMilestone),
              ],
            ],
          ),
          trailing: Column(
            key: const Key('journey_overview_record_pane'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang.translate('record_observance'),
                style: const TextStyle(
                  fontSize: IosText.headline,
                  fontWeight: FontWeight.w600,
                  color: teal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.translate('tap_to_record_instruction'),
                style: _secondary(IosText.caption),
              ),
              ..._recentRows(lang, tracker),
            ],
          ),
        ),
      ],
    );
  }

  /// Two equal-height tiles side by side (a SwiftUI GridRow).
  Widget _pair(Widget a, Widget b, {Key? key}) => IntrinsicHeight(
    key: key,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    ),
  );

  Widget _buildNextMilestoneCard(
    LanguageService lang,
    ({Achievement achievement, int currentProgress, int target}) milestone,
  ) {
    final ratio = milestone.target > 0
        ? (milestone.currentProgress / milestone.target).clamp(0.0, 1.0)
        : 0.0;
    const caption = TextStyle(
      fontSize: IosText.caption,
      fontWeight: FontWeight.w700,
      color: teal,
    );
    return GlassPanel(
      radius: 16,
      tint: teal,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            children: [
              const Icon(AppIcons.journeyMilestone, size: 14, color: teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(lang.translate('next_milestone'), style: caption),
              ),
              Text(
                '${milestone.currentProgress} / ${milestone.target}',
                style: caption,
              ),
            ],
          ),
          Text(
            lang.translate(milestone.achievement.titleKey),
            style: TextStyle(
              fontSize: IosText.headline,
              fontWeight: FontWeight.w600,
              color: IosColors.primary(context),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: teal.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(teal),
            ),
          ),
        ],
      ),
    );
  }

  /// Up to four Ekadashis within 30 days of today.
  List<Widget> _recentRows(LanguageService lang, VratTrackerService tracker) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recent =
        (List<EkadashiDate>.from(widget.ekadashiList)
              ..sort((a, b) => a.date.compareTo(b.date)))
            .where((e) => e.date.difference(today).inDays.abs() <= 30)
            .take(4);
    return [
      for (final e in recent) ...[
        const SizedBox(height: 12),
        _buildEkadashiRow(lang, tracker, e),
      ],
    ];
  }

  // ==================== HISTORY ====================
  Widget _buildHistoryTab(LanguageService lang, VratTrackerService tracker) {
    final columns = AdaptiveLayout.of(context).columns;
    final availableYears = _years(tracker);
    final selectedYear = _coherentSelectedYear(availableYears);
    final filtered = widget.ekadashiList.where((e) {
      if (e.date.year != selectedYear) return false;
      if (_historyStatusFilter == null) return true;
      final status =
          tracker.getRecordByUid(e.occurrenceUid)?.status ??
          ObservanceStatus.unrecorded;
      return status == _historyStatusFilter;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    Widget chip(ObservanceStatus? status, String key) => GlassChip(
      key: Key('journey_filter_${status?.name ?? 'all'}'),
      label: lang.translate(key),
      color: status == null ? teal : vratStatusColor(context, status),
      selected: _historyStatusFilter == status,
      onTap: () => setState(() => _historyStatusFilter = status),
    );

    return Column(
      spacing: 8,
      children: [
        SingleChildScrollView(
          key: const Key('vrat_history_filters_tube'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            spacing: 8,
            children: [
              _yearMenu(
                const Key('journey_history_year_menu'),
                availableYears,
                selectedYear,
              ),
              chip(null, 'filter_all'),
              chip(ObservanceStatus.observed, 'observed'),
              chip(ObservanceStatus.partial, 'partial'),
              chip(ObservanceStatus.missed, 'missed'),
              chip(ObservanceStatus.unrecorded, 'unrecorded'),
            ],
          ),
        ),
        // The instruction scrolls with the rows, so large text keeps the
        // list on screen.
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    lang.translate('tap_to_record_instruction'),
                    textAlign: TextAlign.center,
                    style: _secondary(IosText.caption),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: UnavailableView(
                    icon: AppIcons.journeyEmpty,
                    title: lang.translate('no_ekadashi'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomInset),
                  // Two columns of rows on wide screens.
                  sliver: SliverList.separated(
                    itemCount: (filtered.length / columns).ceil(),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, line) => columns == 1
                        ? _buildEkadashiRow(lang, tracker, filtered[line])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var c = 0; c < columns; c++) ...[
                                if (c > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: line * columns + c < filtered.length
                                      ? _buildEkadashiRow(
                                          lang,
                                          tracker,
                                          filtered[line * columns + c],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The year menu: a teal glass capsule with a calendar icon (iOS Menu).
  Widget _yearMenu(Key key, List<int> years, int selected) =>
      PopupMenuButton<int>(
        key: key,
        tooltip: '',
        position: PopupMenuPosition.under,
        onSelected: (y) => setState(() => _selectedYear = y),
        itemBuilder: (_) => [
          for (final y in years) PopupMenuItem(value: y, child: Text('$y')),
        ],
        child: GlassPanel(
          radius: 999,
          tint: teal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              const Icon(AppIcons.journeyYear, size: 15, color: teal),
              Text(
                '$selected',
                style: const TextStyle(
                  fontSize: IosText.subheadline,
                  fontWeight: FontWeight.w600,
                  color: teal,
                ),
              ),
            ],
          ),
        ),
      );

  /// One Ekadashi: status circle, name and date, the status pill and a
  /// chevron, or a clock while the fast cannot be recorded yet.
  Widget _buildEkadashiRow(
    LanguageService lang,
    VratTrackerService tracker,
    EkadashiDate ekadashi,
  ) {
    final record = tracker.getRecordByUid(ekadashi.occurrenceUid);
    final status = record?.status ?? ObservanceStatus.unrecorded;
    final color = vratStatusColor(context, status);
    final dateStr = AppStrings.fullDate(
      ekadashi.date,
      lang.currentLocale.languageCode,
    );
    final (statusLabel, statusIcon) = switch (status) {
      ObservanceStatus.observed => (
        lang.translate('observed'),
        AppIcons.statusObserved,
      ),
      ObservanceStatus.partial => (
        lang.translate('partial'),
        AppIcons.statusPartial,
      ),
      ObservanceStatus.missed => (
        lang.translate('missed'),
        AppIcons.statusMissed,
      ),
      ObservanceStatus.unrecorded => (
        lang.translate('not_recorded'),
        AppIcons.statusUnrecorded,
      ),
    };
    final open = VratRecording.isOpen(
      ekadashi,
      now: DateTime.now(),
      timezone: widget.currentTimezone,
    );
    final note = record?.note;

    Future<void> onTap() async {
      // Only fasts that have happened can be recorded.
      if (!open) {
        showToast(context, lang.translate('journey_record_after_parana'));
        return;
      }
      final unlocks = await RecordVratDialog.show(
        context,
        ekadashi: ekadashi,
        allOccurrences: widget.ekadashiList,
        currentTimezone: widget.currentTimezone,
      );
      if (unlocks != null && unlocks.isNotEmpty && mounted) {
        for (final u in unlocks) {
          if (!mounted) return;
          await AchievementUnlockDialog.show(context, u);
        }
      }
    }

    return Semantics(
      label:
          '${ekadashi.name}, $dateStr, $statusLabel. ${lang.translate('tap_to_record_semantics')}',
      button: true,
      excludeSemantics: true,
      child: GlassPanel(
        key: Key('journey_row_${ekadashi.occurrenceUid}'),
        radius: 14,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Opacity(
          opacity: open ? 1 : .55,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowWidth = constraints.maxWidth;
              return Row(
                spacing: 12,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(statusIcon, size: 18, color: color),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          ekadashi.name,
                          style: TextStyle(
                            fontSize: IosText.headline,
                            fontWeight: FontWeight.w600,
                            color: IosColors.primary(context),
                          ),
                        ),
                        Text(dateStr, style: _secondary(IosText.footnote)),
                        if (note != null && note.isNotEmpty)
                          Text(
                            '“$note”',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _secondary(
                              IosText.caption,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    // The pill never takes more than 40% of the row, so large
                    // text still leaves the name room to wrap by words.
                    constraints: BoxConstraints(maxWidth: rowWidth * .4),
                    child: StatusPill(text: statusLabel, color: color),
                  ),
                  Icon(
                    open ? AppIcons.rowDisclosure : AppIcons.journeyPending,
                    size: 14,
                    color: IosColors.tertiary(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== STATISTICS ====================
  Widget _buildStatisticsTab(LanguageService lang, VratTrackerService tracker) {
    final availableYears = _years(tracker);
    final selectedYear = _coherentSelectedYear(availableYears);
    final stats = tracker.getAnnualStats(
      year: selectedYear,
      occurrences: widget.ekadashiList,
    );
    final currentStreak = tracker.getCurrentStreak(widget.ekadashiList);
    final longestStreak = tracker.getLongestStreak(widget.ekadashiList);
    final percent = stats.completionPercentage;
    final headline = TextStyle(
      fontSize: IosText.headline,
      fontWeight: FontWeight.w600,
      color: IosColors.primary(context),
    );

    const tileKeys = [
      'observed',
      'partial',
      'missed',
      'unrecorded',
      'current_streak',
      'longest_streak',
    ];
    final labelStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(fontSize: IosText.caption, color: IosColors.primary(context)),
    );

    /// The six tiles are equal: every label gets the height of the tallest.
    double labelHeight(double tileWidth) {
      var height = 0.0;
      for (final key in tileKeys) {
        final painter = TextPainter(
          text: TextSpan(text: lang.translate(key), style: labelStyle),
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(0, tileWidth));
        height = math.max(height, painter.height);
        painter.dispose();
      }
      return height;
    }

    Widget tile(String key, int value, Color color, double label) => GlassPanel(
      key: Key('journey_stat_$key'),
      radius: 14,
      tint: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        spacing: 6,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: IosText.title3,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(
            height: label,
            child: Text(
              lang.translate(key),
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomInset),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${lang.translate('year')}:', style: headline),
            ),
            _yearMenu(
              const Key('journey_stats_year_menu'),
              availableYears,
              selectedYear,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Wide screens show the ring beside the counts.
        AdaptivePanes(
          stackedSpacing: 16,
          leading: GlassPanel(
            radius: 16,
            padding: const EdgeInsets.all(20),
            child: Column(
              spacing: 12,
              children: [
                Text(
                  '$selectedYear ${lang.translate('annual_completion')}',
                  textAlign: TextAlign.center,
                  style: headline,
                ),
                SizedBox(
                  key: const Key('journey_stats_ring'),
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _RingPainter(percent / 100),
                    child: Center(
                      child: Text(
                        '${percent.round()}%',
                        style: const TextStyle(
                          fontSize: IosText.title,
                          fontWeight: FontWeight.w700,
                          color: teal,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  AppStrings.translateWithArgs(
                    'observed_of_total',
                    lang.currentLocale.languageCode,
                    ['${stats.observedCount}', '${stats.totalOccurrences}'],
                  ),
                  textAlign: TextAlign.center,
                  style: _secondary(IosText.subheadline),
                ),
              ],
            ),
          ),
          trailing: LayoutBuilder(
            builder: (context, constraints) {
              final label = labelHeight((constraints.maxWidth - 12) / 2 - 28);
              return Column(
                spacing: 12,
                children: [
                  _pair(
                    tile(
                      'observed',
                      stats.observedCount,
                      IosColors.green(context),
                      label,
                    ),
                    tile(
                      'partial',
                      stats.partialCount,
                      IosColors.partial,
                      label,
                    ),
                  ),
                  _pair(
                    tile('missed', stats.missedCount, IosColors.missed, label),
                    tile(
                      'unrecorded',
                      stats.unrecordedCount,
                      IosColors.gray(context),
                      label,
                    ),
                  ),
                  _pair(
                    tile(
                      'current_streak',
                      currentStreak,
                      IosColors.orange(context),
                      label,
                    ),
                    tile(
                      'longest_streak',
                      longestStreak,
                      IosColors.amber,
                      label,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== ACHIEVEMENTS ====================
  Widget _buildAchievementsTab(
    LanguageService lang,
    VratTrackerService tracker,
  ) {
    const achievements = AchievementEvaluator.allAchievements;
    final userMap = tracker.userAchievements;
    final premium = context.watch<PremiumService?>()?.isPremium == true;
    final freeUsed = userMap.values.where((a) => a.isUnlocked).length;

    Widget card(Achievement ach) {
      final unlocked = userMap[ach.id]?.isUnlocked ?? false;
      final paidLocked =
          !premium &&
          !unlocked &&
          freeUsed >= VratTrackerService.freeAchievementLimit;
      final gray = IosColors.gray(context);
      return Container(
        foregroundDecoration: unlocked
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: teal, width: 1.8),
              )
            : null,
        child: GlassPanel(
          key: Key('journey_achievement_${ach.id}'),
          radius: 16,
          tint: unlocked ? teal : null,
          padding: const EdgeInsets.all(14),
          child: Column(
            spacing: 8,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? teal.withValues(alpha: 0.15)
                      : gray.withValues(alpha: 0.08),
                ),
                child: Icon(
                  unlocked ? ach.icon : AppIcons.achievementLocked,
                  size: 26,
                  color: unlocked ? teal : gray,
                ),
              ),
              Text(
                lang.translate(ach.titleKey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: IosText.footnote,
                  fontWeight: FontWeight.w700,
                  color: unlocked
                      ? IosColors.primary(context)
                      : IosColors.secondary(context),
                ),
              ),
              Text(
                lang.translate(ach.descriptionKey),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _secondary(IosText.caption2),
              ),
              const Spacer(),
              Text(
                unlocked
                    ? '✓ ${lang.translate('unlocked')}'
                    : lang.translate(paidLocked ? 'premium_title' : 'locked'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: IosText.caption,
                  fontWeight: FontWeight.w700,
                  color: unlocked ? teal : IosColors.secondary(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // LazyVGrid(.adaptive(minimum: 150), spacing 12).
        final width = constraints.maxWidth - 32;
        final columns = math.max(1, ((width + 12) / (150 + 12)).floor());
        final rows = <Widget>[];
        for (var i = 0; i < achievements.length; i += columns) {
          rows.add(
            ConstrainedBox(
              // minHeight 190 inside the 14 padding.
              constraints: const BoxConstraints(minHeight: 190 + 28),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (var c = 0; c < columns; c++)
                      Expanded(
                        child: i + c < achievements.length
                            ? card(achievements[i + c])
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomInset),
          children: [
            Text(
              lang.translate('premium_free_achievements'),
              style: TextStyle(
                fontSize: IosText.subheadline,
                color: IosColors.primary(context),
              ),
            ),
            if (!premium) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  key: const Key('journey_more_achievements'),
                  onPressed: () => openPremium(
                    context,
                    currentTimezone: widget.currentTimezone,
                  ),
                  style: IosButtons.glass(context),
                  child: Text(
                    lang.translate('premium_more_achievements'),
                    textAlign: TextAlign.center,
                    style: IosButtons.label,
                  ),
                ),
              ),
            ],
            for (final row in rows) ...[const SizedBox(height: 12), row],
          ],
        );
      },
    );
  }
}

/// iOS overview metric card (MetricCard in VratView.swift).
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.panelKey,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final Key panelKey;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassPanel(
    key: panelKey,
    radius: 16,
    tint: color,
    tintOpacity: .35,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: IosText.title2,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: IosText.caption,
            fontWeight: FontWeight.w500,
            color: IosColors.primary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: IosText.caption2,
            color: IosColors.secondary(context),
          ),
        ),
      ],
    ),
  );
}

/// The statistics progress ring: a pale teal track and a round-capped teal
/// arc from the top, 12 wide (iOS Circle().trim).
class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = IosColors.teal.withValues(alpha: .15);
    canvas.drawOval(circle, paint);
    final value = progress.clamp(0.0, 1.0);
    if (value <= 0) return;
    canvas.drawArc(
      circle,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      paint
        ..color = IosColors.teal
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
