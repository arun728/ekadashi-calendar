import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../l10n/app_language.dart';
import '../../services/journey_rewards.dart';
import '../../services/vrat_tracker_service.dart';
import '../../services/language_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/ios_style.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/settings_group.dart';
import '../../widgets/app_background.dart';
import '../premium_screen.dart';
import 'journey_artwork.dart';

const journeyCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color.fromRGBO(5, 46, 46, 1), Color.fromRGBO(8, 20, 33, 1)],
);
const journeyCardMatte = Color.fromRGBO(5, 36, 36, 1);
TextStyle _secondaryBright(double size) =>
    TextStyle(fontSize: size, color: const Color(0xBFFFFFFF));

String _t(BuildContext c, String key, [List<String> args = const []]) =>
    AppStrings.translateWithArgs(
      key,
      c.read<LanguageService>().currentLocale.languageCode,
      args,
    );
TextStyle _secondary(BuildContext c, [double size = 12]) =>
    TextStyle(fontSize: size, color: IosColors.secondary(c));
Widget _progress(int value, int target) => ClipRRect(
  borderRadius: BorderRadius.circular(2),
  child: LinearProgressIndicator(
    value: value / math.max(1, target),
    minHeight: 4,
    color: IosColors.teal,
    backgroundColor: IosColors.teal.withValues(alpha: .15),
  ),
);

class JourneyOverviewPanel extends StatelessWidget {
  const JourneyOverviewPanel({
    super.key,
    required this.summary,
    required this.year,
  });
  final JourneySummary summary;
  final int year;
  @override
  Widget build(BuildContext context) {
    final p = summary.year(year), tracker = context.watch<VratTrackerService>();
    final premium = context.watch<PremiumService?>()?.isPremium == true,
        lang = context.watch<LanguageService>();
    final now = DateTime.now(),
        currentQuarter = year == DateTime.now().year
            ? (now.month - 1) ~/ 3 + 1
            : 1;
    final badges = JourneyBadgeCatalog.all([year])
        .where(
          (b) =>
              tracker.userAchievements[b.id]?.isUnlocked == true &&
              (b.year == null || b.year == year),
        )
        .toList();
    return Theme(
      data: ThemeData(brightness: Brightness.dark),
      child: Builder(
        builder: (context) => DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Container(
            key: const Key('journey_overview_surface'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: journeyCardGradient,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              spacing: 14,
              children: [
                if (tracker.rewardsStorageError)
                  Text(
                    _t(context, 'ios_journey_storage_error'),
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                Semantics(
                  key: const Key('journey_year_points'),
                  container: true,
                  child: Column(
                    spacing: 6,
                    children: [
                      Text(
                        _t(context, 'ios_journey_title', ['$year']),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        NumberFormat.decimalPattern(
                          lang.currentLocale.languageCode,
                        ).format(p.points),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: IosColors.teal,
                        ),
                      ),
                      Text(
                        _t(context, 'ios_journey_points'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _t(context, 'ios_journey_year_points', [
                          '${p.points}',
                          '${p.maximumPoints}',
                        ]),
                        style: _secondary(context),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 310),
                  child: JourneyMandala(progress: p),
                ),
                Text(
                  _t(context, 'ios_journey_summary', [
                    '${p.observed}',
                    '${p.partial}',
                  ]),
                  style: _secondaryBright(15),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      AppIcons.journeyStreak,
                      size: 17,
                      color: IosColors.teal,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_t(context, 'current_streak')} · ${summary.currentStreak}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: IosColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  key: const Key('journey_lifetime_points'),
                  children: [
                    Expanded(
                      child: Text(
                        _t(context, 'ios_journey_lifetime'),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      NumberFormat.decimalPattern(
                        lang.currentLocale.languageCode,
                      ).format(summary.lifetimePoints),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                for (final q in p.quarters)
                  MergeSemantics(
                    key: Key('journey_quarter_${year}_${q.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _t(context, 'ios_journey_quarter', [
                                  '${q.id}',
                                  '$year',
                                ]),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _t(context, 'ios_journey_quarter_progress', [
                                  '${q.observed}',
                                  '${q.total}',
                                ]),
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        _progress(q.observed, q.total),
                        if (q.completed || q.id == currentQuarter)
                          Text(
                            _t(
                              context,
                              q.completed
                                  ? 'ios_journey_bonus_earned'
                                  : 'ios_journey_quarter_bonus',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: q.completed
                                  ? IosColors.teal
                                  : const Color(0xBFFFFFFF),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (p.annualBonus > 0)
                  Text(
                    _t(context, 'ios_journey_annual_bonus'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: IosColors.teal,
                    ),
                  ),
                Text(
                  _t(context, 'ios_journey_scoring'),
                  textAlign: TextAlign.center,
                  style: _secondaryBright(11),
                ),
                Text(
                  _t(context, 'ios_journey_personal'),
                  style: _secondaryBright(11),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('journey_share_year'),
                    style: IosButtons.prominent(),
                    onPressed: () => showAppSheet<void>(
                      context,
                      builder: (_) =>
                          JourneyShareSheet(progress: p, badges: badges),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(AppIcons.share, size: 17),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _t(context, 'ios_journey_share'),
                            style: IosButtons.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!premium)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('journey_rewards_premium'),
                      style: IosButtons.prominent(),
                      onPressed: () => openPremium(
                        context,
                        reasonKey: 'ios_journey_premium_desc',
                      ),
                      child: Column(
                        spacing: 4,
                        children: [
                          Text(
                            _t(context, 'ios_journey_premium'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _t(context, 'ios_journey_premium_desc'),
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JourneyBadgeCollection extends StatefulWidget {
  const JourneyBadgeCollection({
    super.key,
    required this.summary,
    this.selectedYear,
    this.years = const [2026, 2027],
  });
  final int? selectedYear;
  final List<int> years;
  final JourneySummary summary;
  @override
  State<JourneyBadgeCollection> createState() => _JourneyBadgeCollectionState();
}

class _JourneyBadgeCollectionState extends State<JourneyBadgeCollection> {
  String? collection;
  String group(JourneyBadgeDefinition b) => switch (b.rule) {
    JourneyRule.observed => 'milestones',
    JourneyRule.streak => 'consistency',
    JourneyRule.partial || JourneyRule.returned => 'encouragement',
    _ => 'annual',
  };
  @override
  Widget build(BuildContext context) {
    context.watch<LanguageService>();
    final tracker = context.watch<VratTrackerService>(),
        premium = context.watch<PremiumService?>()?.isPremium == true,
        earned = tracker.userAchievements;
    final definitions =
        JourneyBadgeCatalog.all(widget.years)
            .where(
              (b) =>
                  b.isVisibleInYear(widget.selectedYear) &&
                  (b.id != 'full_year_observance' ||
                      earned[b.id]?.isUnlocked == true) &&
                  (collection == null || group(b) == collection),
            )
            .toList()
          ..sort((a, b) {
            final ea = earned[a.id]?.isUnlocked == true,
                eb = earned[b.id]?.isUnlocked == true;
            if (ea != eb) return ea ? -1 : 1;
            final order = a.achievement.sortOrder.compareTo(
              b.achievement.sortOrder,
            );
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    Widget card(JourneyBadgeDefinition b) {
      final unlocked = earned[b.id]?.isUnlocked == true;
      final (value, target) = badgeDisplayedProgress(b, widget.summary);
      return GestureDetector(
        key: Key('journey_badge_${b.id}'),
        onTap: () => JourneyBadgeDetail.show(context, b, widget.summary),
        child: Semantics(
          button: true,
          child: GlassPanel(
            key: Key('journey_achievement_${b.id}'),
            radius: 18,
            tint: unlocked ? IosColors.teal : null,
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 210),
              child: Column(
                spacing: 8,
                children: [
                  JourneyBadgeArt(definition: b, earned: unlocked),
                  Text(
                    _t(context, b.achievement.titleKey),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (b.year != null)
                    Text(
                      '${b.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: IosColors.teal,
                      ),
                    ),
                  Text(
                    _t(context, b.achievement.descriptionKey),
                    textAlign: TextAlign.center,
                    style: _secondary(context),
                  ),
                  if (unlocked)
                    Text(
                      _t(context, 'unlocked'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: IosColors.teal,
                      ),
                    )
                  else ...[
                    Text(
                      _t(context, 'ios_journey_progress', [
                        '$value',
                        '$target',
                      ]),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (!premium &&
                        earned.values.where((a) => a.isUnlocked).length >= 3)
                      Text(
                        _t(context, 'premium_title'),
                        style: _secondary(context, 11),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTextStyle.merge(
      style: TextStyle(color: IosColors.primary(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              _t(context, 'ios_journey_badges'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  GlassChip(
                    key: const Key('journey_badge_filter_all'),
                    label: _t(context, 'filter_all'),
                    color: IosColors.teal,
                    selected: collection == null,
                    onTap: () => setState(() => collection = null),
                  ),
                  for (final g in [
                    'milestones',
                    'consistency',
                    'encouragement',
                    'annual',
                  ])
                    GlassChip(
                      key: Key('journey_badge_filter_$g'),
                      label: _t(context, 'ios_journey_collection_$g'),
                      color: IosColors.teal,
                      selected: collection == g,
                      onTap: () => setState(() => collection = g),
                    ),
                ],
              ),
            ),
            Text(
              _t(context, 'premium_free_achievements'),
              style: _secondary(context, 15),
            ),
            if (!premium)
              OutlinedButton(
                key: const Key('journey_more_achievements'),
                style: IosButtons.glass(context),
                onPressed: () => openPremium(context),
                child: Text(
                  _t(context, 'premium_more_achievements'),
                  style: IosButtons.label,
                ),
              ),
            LayoutBuilder(
              builder: (context, c) {
                final columns = math.max(1, ((c.maxWidth + 12) / 157).floor());
                return Column(
                  spacing: 12,
                  children: [
                    for (var i = 0; i < definitions.length; i += columns)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [
                            for (var j = 0; j < columns; j++)
                              Expanded(
                                child: i + j < definitions.length
                                    ? card(definitions[i + j])
                                    : const SizedBox(),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

(int, int) badgeDisplayedProgress(JourneyBadgeDefinition b, JourneySummary s) =>
    switch (b.rule) {
      JourneyRule.quarter => (
        s.year(b.year!).quarters[b.quarter! - 1].observed,
        s.year(b.year!).quarters[b.quarter! - 1].total,
      ),
      JourneyRule.annual => (
        s.year(b.year!).observed,
        s.year(b.year!).segments.length,
      ),
      _ => (b.progress(s), b.target),
    };

class JourneyBadgeDetail extends StatelessWidget {
  const JourneyBadgeDetail({
    super.key,
    required this.definition,
    required this.summary,
  });
  final JourneyBadgeDefinition definition;
  final JourneySummary summary;
  static Future<void> show(
    BuildContext c,
    JourneyBadgeDefinition b,
    JourneySummary s,
  ) => showAppSheet<void>(
    c,
    builder: (_) => JourneyBadgeDetail(definition: b, summary: s),
  );
  @override
  Widget build(BuildContext context) {
    context.watch<LanguageService>();
    final tracker = context.watch<VratTrackerService?>(),
        earned = tracker?.userAchievements[definition.id];
    final (value, target) = badgeDisplayedProgress(definition, summary);
    final stamp = DateTime.tryParse(earned?.unlockedAtUTC ?? '');
    DateTime? date = stamp;
    if (stamp != null) {
      try {
        date = tz.TZDateTime.from(
          stamp,
          tz.getLocation(tracker?.journeyTimezone ?? 'Asia/Kolkata'),
        );
      } catch (_) {
        date = stamp.toUtc();
      }
    }
    return DefaultTextStyle.merge(
      style: TextStyle(color: IosColors.primary(context)),
      child: AppBackground(
        child: Column(
          key: const Key('journey_badge_detail'),
          children: [
            SheetBar(
              title: '',
              trailing: BarTextButton(
                label: _t(context, 'info_close'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  spacing: 18,
                  children: [
                    JourneyBadgeArt(
                      definition: definition,
                      earned: earned?.isUnlocked == true,
                      size: 160,
                    ),
                    Text(
                      _t(context, definition.achievement.titleKey),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (definition.year != null)
                      Text(
                        '${definition.year}',
                        style: const TextStyle(
                          fontSize: 17,
                          color: IosColors.teal,
                        ),
                      ),
                    Text(
                      _t(context, definition.achievement.descriptionKey),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _t(
                        context,
                        earned?.isUnlocked == true ? 'unlocked' : 'locked',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: IosColors.teal,
                      ),
                    ),
                    _progress(value, target),
                    Text(
                      _t(context, 'ios_journey_progress', [
                        '$value',
                        '$target',
                      ]),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (date != null)
                      Text(
                        _t(context, 'ios_journey_earned', [
                          AppStrings.fullDate(
                            date,
                            context
                                .read<LanguageService>()
                                .currentLocale
                                .languageCode,
                          ),
                        ]),
                        style: _secondary(context),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyShareSheet extends StatefulWidget {
  const JourneyShareSheet({
    super.key,
    required this.progress,
    required this.badges,
  });
  final JourneyYear progress;
  final List<JourneyBadgeDefinition> badges;
  @override
  State<JourneyShareSheet> createState() => _JourneyShareSheetState();
}

class _JourneyShareSheetState extends State<JourneyShareSheet> {
  final boundary = GlobalKey();
  late final selected = widget.badges.take(3).map((b) => b.id).toSet();
  bool sharing = false;
  Future<void> share() async {
    setState(() => sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || data == null) return;
      await Share.shareXFiles(
        [
          XFile.fromData(
            data.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'journey-${widget.progress.year}.png',
          ),
        ],
        text: _t(context, 'ios_journey_share_message', [
          '${widget.progress.year}',
          '${widget.progress.points}',
        ]),
      );
    } catch (_) {
      if (mounted) showToast(context, _t(context, 'storage_failed'));
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageService>();
    return AppBackground(
      child: Column(
        children: [
          SheetBar(
            title: _t(context, 'ios_journey_share_preview'),
            leading: BarTextButton(
              label: _t(context, 'cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                spacing: 20,
                children: [
                  FittedBox(
                    child: RepaintBoundary(
                      key: boundary,
                      child: SizedBox(
                        width: 360,
                        child: JourneyAnnualShareCard(
                          key: const Key('journey_share_preview'),
                          progress: widget.progress,
                          badges: widget.badges
                              .where((b) => selected.contains(b.id))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  for (final b in widget.badges)
                    SettingsSwitchTile(
                      title: Text(_t(context, b.achievement.titleKey)),
                      value: selected.contains(b.id),
                      onChanged: (v) => setState(() {
                        if (v) {
                          selected.add(b.id);
                        } else {
                          selected.remove(b.id);
                        }
                      }),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('journey_share_confirm'),
                      style: IosButtons.prominent(),
                      onPressed: sharing ? null : share,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(AppIcons.share),
                          const SizedBox(width: 8),
                          Text(_t(context, 'share'), style: IosButtons.label),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JourneyAnnualShareCard extends StatelessWidget {
  const JourneyAnnualShareCard({
    super.key,
    required this.progress,
    required this.badges,
  });
  final JourneyYear progress;
  final List<JourneyBadgeDefinition> badges;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: journeyCardMatte,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Theme(
        data: ThemeData(brightness: Brightness.dark),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: journeyCardGradient,
            ),
            child: Column(
              spacing: 12,
              children: [
                Text(
                  _t(context, 'ios_journey_title', ['${progress.year}']),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: JourneyMandala(progress: progress),
                ),
                Text(
                  '${NumberFormat.decimalPattern(context.read<LanguageService>().currentLocale.languageCode).format(progress.points)} ${_t(context, 'ios_journey_points')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _t(context, 'ios_journey_summary', [
                    '${progress.observed}',
                    '${progress.partial}',
                  ]),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final b in badges)
                        JourneyBadgeArt(definition: b, size: 46),
                    ],
                  ),
                ),
                Text(
                  _t(context, 'app_title'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xB3FFFFFF),
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
