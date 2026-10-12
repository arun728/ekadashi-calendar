import '../premium_screen.dart';
import '../../services/premium_service.dart';
import '../../widgets/glass_tube.dart';
import '../../widgets/section_pager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vrat_tracker_models.dart';
import '../../services/achievement_evaluator.dart';
import '../../services/ekadashi_service.dart';
import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import '../../services/vrat_recording.dart';
import '../../services/vrat_statistics_service.dart';
import '../../services/vrat_tracker_service.dart';
import 'achievement_unlock_dialog.dart';
import 'record_vrat_dialog.dart';

/// Combined Vrat Tracker and Achievement System screen (Module 04).
/// Integrates Overview, History, Statistics, and Achievements in a calm, devotional interface.
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
  static const Color tealColor = Color(0xFF00A19B);

  final _pages = PageController();
  var _section = _JourneySection.overview;
  int _selectedYear = DateTime.now().year;
  ObservanceStatus? _historyStatusFilter;

  @override
  void initState() {
    super.initState();

    // Initialize tracker service with occurrences if not already done
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.translate('tracker_storage_failed'),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => tracker.init(occurrences: widget.ekadashiList),
              child: Text(lang.translate('retry')),
            ),
          ],
        ),
      );
    }

    // 2. ACTIVE TRACKER DASHBOARD: the sections are glass chips, as in
    // Panchang, and also change with a horizontal swipe.
    const sections = _JourneySection.values;
    // Chips need a Material; the shell's Scaffold is not always above.
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

  // ==================== 2. OVERVIEW TAB ====================
  Widget _buildOverviewTab(LanguageService lang, VratTrackerService tracker) {
    final currentStreak = tracker.getCurrentStreak(widget.ekadashiList);
    final longestStreak = tracker.getLongestStreak(widget.ekadashiList);
    final selectedYear = _coherentSelectedYear(
      VratStatisticsService.getAvailableYears(
        occurrences: widget.ekadashiList,
        history: tracker.getAllRecords(),
      ),
    );
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Streak & Total Cards Grid
        Row(
          key: const Key('journey_overview_streaks'),
          children: [
            Expanded(
              child: _buildMetricCard(
                title: lang.translate('current_streak'),
                value: '$currentStreak',
                subtitle: lang.translate('ekadashis_unit'),
                icon: Icons.local_fire_department_outlined,
                accentColor: Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: lang.translate('longest_streak'),
                value: '$longestStreak',
                subtitle: lang.translate('ekadashis_unit'),
                icon: Icons.military_tech_outlined,
                accentColor: Colors.amber.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: '$selectedYear ${lang.translate('annual_completion')}',
                value: '${yearStats.completionPercentage.toStringAsFixed(0)}%',
                subtitle:
                    '${yearStats.observedCount} / ${yearStats.totalOccurrences}',
                icon: Icons.donut_large_outlined,
                accentColor: tealColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: lang.translate('total_observed'),
                value: '$totalObserved',
                subtitle: lang.translate('ekadashis_unit'),
                icon: Icons.check_circle_outline,
                accentColor: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Next Milestone Progress Card
        if (nextMilestone != null) ...[
          _buildNextMilestoneCard(lang, nextMilestone),
          const SizedBox(height: 20),
        ],

        // Quick Observance Card for Upcoming / Recent Ekadashis
        Text(
          lang.translate('record_observance'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: tealColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lang.translate('tap_to_record_instruction'),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        _buildRecentEkadashiQuickLog(lang, tracker),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 22),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMilestoneCard(
    LanguageService lang,
    ({Achievement achievement, int currentProgress, int target}) milestone,
  ) {
    final title = lang.translate(milestone.achievement.titleKey);
    final double ratio = milestone.target > 0
        ? (milestone.currentProgress / milestone.target).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tealColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tealColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.flag_outlined, size: 20, color: tealColor),
              const SizedBox(width: 8),
              Text(
                lang.translate('next_milestone'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),

              Text(
                '${milestone.currentProgress} / ${milestone.target}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: tealColor.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(tealColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEkadashiQuickLog(
    LanguageService lang,
    VratTrackerService tracker,
  ) {
    if (widget.ekadashiList.isEmpty) return const SizedBox.shrink();

    // Show upcoming or recent 3 Ekadashis
    final sorted = List<EkadashiDate>.from(widget.ekadashiList)
      ..sort((a, b) => a.date.compareTo(b.date));

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    // Find closest to today
    final recent = sorted
        .where((e) {
          final diff = e.date.difference(today).inDays;
          return diff >= -30 && diff <= 30;
        })
        .take(4)
        .toList();

    return Column(
      children: recent
          .map((e) => _buildEkadashiListTile(lang, tracker, e))
          .toList(),
    );
  }

  // ==================== 3. HISTORY TAB ====================
  Widget _buildHistoryTab(LanguageService lang, VratTrackerService tracker) {
    final availableYears = VratStatisticsService.getAvailableYears(
      occurrences: widget.ekadashiList,
      history: tracker.getAllRecords(),
    );
    final selectedYear = _coherentSelectedYear(availableYears);

    // Filter occurrences by selected year
    var filtered = widget.ekadashiList
        .where((e) => e.date.year == selectedYear)
        .toList();

    // Filter by status if set
    if (_historyStatusFilter != null) {
      filtered = filtered.where((e) {
        final record = tracker.getRecordByUid(e.occurrenceUid);
        final status = record?.status ?? ObservanceStatus.unrecorded;
        return status == _historyStatusFilter;
      }).toList();
    }

    filtered.sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        // Year & Status Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GlassTube(
            key: const Key('vrat_history_filters_tube'),
            optionCount: 6,
            child: Row(
              children: [
                // Year Dropdown
                DropdownButton<int>(
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  value: selectedYear,
                  underline: const SizedBox.shrink(),
                  items: availableYears.map((y) {
                    return DropdownMenuItem(
                      value: y,
                      child: Text(
                        '$y',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (y) {
                    if (y != null) setState(() => _selectedYear = y);
                  },
                ),
                const SizedBox(width: 8),
                // Status Filter Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GlassFilterChip(
                          label: Text(lang.translate('filter_all')),
                          selected: _historyStatusFilter == null,
                          onSelected: (_) =>
                              setState(() => _historyStatusFilter = null),
                        ),
                        const SizedBox(width: 6),
                        GlassFilterChip(
                          label: Text(lang.translate('observed')),
                          selected:
                              _historyStatusFilter == ObservanceStatus.observed,
                          onSelected: (_) => setState(
                            () => _historyStatusFilter =
                                ObservanceStatus.observed,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GlassFilterChip(
                          label: Text(lang.translate('partial')),
                          selected:
                              _historyStatusFilter == ObservanceStatus.partial,
                          onSelected: (_) => setState(
                            () =>
                                _historyStatusFilter = ObservanceStatus.partial,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GlassFilterChip(
                          label: Text(lang.translate('missed')),
                          selected:
                              _historyStatusFilter == ObservanceStatus.missed,
                          onSelected: (_) => setState(
                            () =>
                                _historyStatusFilter = ObservanceStatus.missed,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GlassFilterChip(
                          label: Text(lang.translate('unrecorded')),
                          selected:
                              _historyStatusFilter ==
                              ObservanceStatus.unrecorded,
                          onSelected: (_) => setState(
                            () => _historyStatusFilter =
                                ObservanceStatus.unrecorded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              lang.translate('tap_to_record_instruction'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        const Divider(height: 1),

        // List of Ekadashis
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    lang.translate('no_ekadashi'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) =>
                      _buildEkadashiListTile(lang, tracker, filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEkadashiListTile(
    LanguageService lang,
    VratTrackerService tracker,
    EkadashiDate ekadashi,
  ) {
    final record = tracker.getRecordByUid(ekadashi.occurrenceUid);
    final status = record?.status ?? ObservanceStatus.unrecorded;
    final dateStr = AppStrings.fullDate(
      ekadashi.date,
      lang.currentLocale.languageCode,
    );

    Color chipColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case ObservanceStatus.observed:
        chipColor = Colors.green;
        statusLabel = lang.translate('observed');
        statusIcon = Icons.check_circle_outline;
        break;
      case ObservanceStatus.partial:
        chipColor = Colors.amber.shade700;
        statusLabel = lang.translate('partial');
        statusIcon = Icons.adjust;
        break;
      case ObservanceStatus.missed:
        chipColor = Colors.red.shade400;
        statusLabel = lang.translate('missed');
        statusIcon = Icons.highlight_off;
        break;
      case ObservanceStatus.unrecorded:
        chipColor = Colors.grey;
        statusLabel = lang.translate('not_recorded');
        statusIcon = Icons.help_outline;
        break;
    }

    final accessibilityLabel =
        '${ekadashi.name}, $dateStr, $statusLabel. ${lang.translate('tap_to_record_semantics')}';

    final open = VratRecording.isOpen(
      ekadashi,
      now: DateTime.now(),
      timezone: widget.currentTimezone,
    );
    return Opacity(
      opacity: open ? 1 : .55,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (!open) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(lang.translate('journey_record_after_parana')),
                ),
              );
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
                await AchievementUnlockDialog.show(context, u);
              }
            }
          },
          child: Semantics(
            label: accessibilityLabel,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Circular indicator on the left
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chipColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: chipColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(statusIcon, size: 18, color: chipColor),
                  ),
                  const SizedBox(width: 12),

                  // Center: Ekadashi name & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ekadashi.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                        if (record?.note != null &&
                            record!.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '“${record.note!}”',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right: Status Badge + Chevron (NO CHECKBOX)
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: chipColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: chipColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: chipColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 4. STATISTICS TAB ====================
  Widget _buildStatisticsTab(LanguageService lang, VratTrackerService tracker) {
    final availableYears = VratStatisticsService.getAvailableYears(
      occurrences: widget.ekadashiList,
      history: tracker.getAllRecords(),
    );

    final selectedYear = _coherentSelectedYear(availableYears);
    final stats = tracker.getAnnualStats(
      year: selectedYear,
      occurrences: widget.ekadashiList,
    );
    final currentStreak = tracker.getCurrentStreak(widget.ekadashiList);
    final longestStreak = tracker.getLongestStreak(widget.ekadashiList);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Year Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${lang.translate('year')}:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              value: selectedYear,
              items: availableYears.map((y) {
                return DropdownMenuItem(value: y, child: Text('$y'));
              }).toList(),
              onChanged: (y) {
                if (y != null) setState(() => _selectedYear = y);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Annual Completion Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tealColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                '$selectedYear ${lang.translate('annual_completion')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${stats.completionPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.translateWithArgs(
                  'observed_of_total',
                  lang.currentLocale.languageCode,
                  ['${stats.observedCount}', '${stats.totalOccurrences}'],
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Observance Breakdown Cards
        Row(
          children: [
            Expanded(
              child: _buildBreakdownItem(
                lang.translate('observed'),
                '${stats.observedCount}',
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBreakdownItem(
                lang.translate('partial'),
                '${stats.partialCount}',
                Colors.amber.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBreakdownItem(
                lang.translate('missed'),
                '${stats.missedCount}',
                Colors.red.shade400,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBreakdownItem(
                lang.translate('unrecorded'),
                '${stats.unrecordedCount}',
                Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Streaks Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildStreakRow(
                lang.translate('current_streak'),
                currentStreak,
                Icons.local_fire_department,
                Colors.orange,
              ),
              const Divider(),
              _buildStreakRow(
                lang.translate('longest_streak'),
                longestStreak,
                Icons.military_tech,
                Colors.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _coherentSelectedYear(List<int> availableYears) {
    if (availableYears.contains(_selectedYear)) return _selectedYear;
    if (availableYears.contains(DateTime.now().year)) {
      return DateTime.now().year;
    }
    return availableYears.first;
  }

  Widget _buildBreakdownItem(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakRow(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==================== 5. ACHIEVEMENTS TAB ====================
  Widget _buildAchievementsTab(
    LanguageService lang,
    VratTrackerService tracker,
  ) {
    const achievements = AchievementEvaluator.allAchievements;
    final userMap = tracker.userAchievements;

    final premium = context.watch<PremiumService?>()?.isPremium == true;
    final freeUsed = userMap.values.where((a) => a.isUnlocked).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(lang.translate('premium_free_achievements')),
        ),
        if (!premium)
          TextButton(
            onPressed: () =>
                openPremium(context, currentTimezone: widget.currentTimezone),
            child: Text(lang.translate('premium_more_achievements')),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  MediaQuery.sizeOf(context).width < 350 ||
                      MediaQuery.textScalerOf(context).scale(12) > 18
                  ? 1
                  : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: achievements.length,
            itemBuilder: (ctx, i) {
              final ach = achievements[i];
              final userAch = userMap[ach.id];
              final isUnlocked = userAch?.isUnlocked ?? false;
              final paidLocked =
                  !premium &&
                  !isUnlocked &&
                  freeUsed >= VratTrackerService.freeAchievementLimit;

              final title = lang.translate(ach.titleKey);
              final desc = lang.translate(ach.descriptionKey);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? tealColor
                        : Colors.grey.withValues(alpha: 0.2),
                    width: isUnlocked ? 1.8 : 1,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: tealColor.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUnlocked
                            ? tealColor.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        isUnlocked ? ach.icon : Icons.lock_outline,
                        size: 26,
                        color: isUnlocked ? tealColor : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? null : Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Expanded(
                      child: Text(
                        desc,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color
                              ?.withValues(alpha: isUnlocked ? 0.75 : 0.45),
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Status badge
                    Text(
                      isUnlocked
                          ? '✓ ${lang.translate('unlocked')}'
                          : lang.translate(
                              paidLocked ? 'premium_title' : 'locked',
                            ),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? tealColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
