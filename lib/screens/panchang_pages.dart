import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/panchang/calculated_ekadashi.dart';
import '../services/panchang/observance_calendar_service.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_key_days.dart';
import '../services/panchang/panchang_models.dart';
import '../services/panchang/panchang_terms.dart';
import '../services/premium_service.dart';
import '../services/search/search_catalog.dart';
import '../widgets/glass_tube.dart';
import 'global_search_screen.dart' show searchCategoryIcon;
import 'premium_screen.dart';

/// Colours shared by the Panchang pages (the iOS Theme).
abstract final class PanchangColors {
  static const teal = GlassTubeColors.teal;
  static const good = Color(0xFF22C55E);
  static const avoid = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
}

String _lang(BuildContext context) =>
    context.watch<LanguageService>().currentLocale.languageCode;

String _t(BuildContext context, String key, [List<String> args = const []]) =>
    AppStrings.translateWithArgs(key, _lang(context), args);

/// A titled card.
class PanchangCard extends StatelessWidget {
  const PanchangCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });
  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PanchangPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: PanchangColors.teal),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// A rounded glass surface.
class PanchangPanel extends StatelessWidget {
  const PanchangPanel({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (tint ?? (dark ? Colors.white : Colors.white)).withValues(
              alpha: dark
                  ? (tint == null ? .08 : .16)
                  : (tint == null ? .9 : .14),
            ),
            (tint ?? (dark ? Colors.white : const Color(0xFFF1F6F5)))
                .withValues(alpha: dark ? .04 : (tint == null ? .8 : .06)),
          ],
        ),
        border: Border.all(
          color: GlassTubeColors.foreground(context).withValues(alpha: .12),
        ),
      ),
      child: child,
    );
  }
}

/// A label on the left and a value (with an optional detail) on the right.
class PanchangValueRow extends StatelessWidget {
  const PanchangValueRow({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.color,
    this.trailing,
  });
  final String label;
  final String value;
  final String? detail;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (color != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: CircleAvatar(radius: 4, backgroundColor: color),
            ),
          Expanded(
            child: Text(label, style: TextStyle(color: muted, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A small coloured capsule.
class PanchangPill extends StatelessWidget {
  const PanchangPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The paywall card for Premium Panchang sections.
class PanchangUpgradeCard extends StatelessWidget {
  const PanchangUpgradeCard({super.key});

  @override
  Widget build(BuildContext context) => PanchangPanel(
    tint: PanchangColors.teal,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock, color: PanchangColors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(context, 'panchang_premium_title'),
                style: const TextStyle(
                  color: PanchangColors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t(context, 'panchang_premium_body'),
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('panchang_unlock_button'),
            style: FilledButton.styleFrom(
              backgroundColor: PanchangColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => openPremium(context),
            icon: const Icon(Icons.star),
            label: Text(_t(context, 'panchang_unlock')),
          ),
        ),
      ],
    ),
  );
}

// MARK: Key days

/// The month's Ekadashis (free) and Panchang observances (Premium), with
/// type filters (docs/ROADMAP.md Phase 3).
class PanchangKeyDaysView extends StatefulWidget {
  const PanchangKeyDaysView({
    super.key,
    required this.month,
    required this.city,
    required this.ekadashiList,
    required this.onOpen,
  });
  final DateTime month;
  final PanchangCity city;
  final List<EkadashiDate> ekadashiList;
  final ValueChanged<DateTime> onOpen;

  @override
  State<PanchangKeyDaysView> createState() => _PanchangKeyDaysViewState();
}

class _PanchangKeyDaysViewState extends State<PanchangKeyDaysView> {
  List<DatedObservance>? _observances;
  SearchCatalog? _catalog;
  SearchCategory? _category;
  String _loadedKey = '';

  static final _filters = SearchCategory.filters
      .where((c) => c != SearchCategory.myCalendar)
      .toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(PanchangKeyDaysView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    final key =
        '${widget.month.year}|${widget.city.id}|${widget.city.latitude}|${widget.city.longitude}|${widget.city.timeZoneId}';
    if (key == _loadedKey) return;
    _loadedKey = key;
    final cached = ObservanceCalendarService.instance.cached(
      widget.month.year,
      widget.city,
    );
    setState(() => _observances = cached);
    final catalog = await SearchCatalog.load();
    final observances =
        cached ??
        await ObservanceCalendarService.instance.year(
          widget.month.year,
          widget.city,
        );
    if (!mounted || key != _loadedKey) return;
    setState(() {
      _catalog = catalog;
      _observances = observances;
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = _lang(context);
    final premium = context.select<PremiumService?, bool>(
      (s) => s?.isPremium ?? false,
    );
    final observances = _observances, catalog = _catalog;
    final days = observances == null || catalog == null
        ? null
        : PanchangKeyDays.filter(
            PanchangKeyDays.month(
              widget.month,
              observances: observances,
              ekadashis: widget.ekadashiList,
              language: language,
              catalog: catalog,
            ),
            _category,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          key: const Key('panchang_key_day_filters'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(context, null),
              for (final type in _filters) _chip(context, type),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!premium) ...[
          PanchangPanel(
            tint: PanchangColors.amber,
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lock,
                    color: PanchangColors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(context, 'panchang_key_days_locked'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: const Key('panchang_key_days_unlock'),
                          onPressed: () => openPremium(context),
                          child: Text(_t(context, 'panchang_unlock_short')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (days == null)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: CircularProgressIndicator(color: PanchangColors.teal),
            ),
          )
        else if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                _t(context, 'panchang_no_key_days'),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          )
        else
          Column(
            key: const Key('panchang_key_days'),
            children: [
              for (final day in days)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _row(context, day, premium, language),
                ),
            ],
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, SearchCategory? type) {
    final selected = _category == type;
    final color = type == null ? PanchangColors.teal : Color(type.color);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        key: Key('panchang_key_filter_${type?.raw ?? 'all'}'),
        avatar: type == null
            ? null
            : Icon(searchCategoryIcon(type), size: 16, color: color),
        label: Text(
          _t(context, type == null ? 'filter_all' : type.localizationKey),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: color.withValues(alpha: .18),
        shape: const StadiumBorder(),
        onSelected: (_) =>
            setState(() => _category = selected || type == null ? null : type),
      ),
    );
  }

  Widget _row(BuildContext context, KeyDay day, bool premium, String language) {
    final type = day.categories.contains(SearchCategory.festival)
        ? SearchCategory.festival
        : day.categories.firstOrNull ?? SearchCategory.festival;
    final color = Color(type.color);
    final locked = day.requiresPremium && !premium;
    return Material(
      key: Key('panchang_key_day_${day.id}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => locked ? openPremium(context) : widget.onOpen(day.date),
        child: PanchangPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: locked
                    ? const Icon(Icons.lock, color: PanchangColors.amber)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.date.day}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              PanchangFormat.weekday(day.date, language),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _t(context, type.localizationKey),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!locked)
                            TextSpan(
                              text: ' · ${_countdown(context, day.date)}',
                            ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock : Icons.chevron_right,
                size: 18,
                color: locked
                    ? PanchangColors.amber
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countdown(BuildContext context, DateTime date) {
    final now = widget.city.wallClock(DateTime.now());
    final today = DateTime.utc(now.year, now.month, now.day);
    final days = date.difference(today).inDays;
    if (days == 0) return _t(context, 'today');
    if (days == 1) return _t(context, 'tomorrow');
    if (days > 1) return _t(context, 'in_days', ['$days']);
    return _t(context, 'panchang_days_ago', ['${-days}']);
  }
}

// MARK: Daily

/// The day at a glance: tithi, sun and moon (free), then the five limbs,
/// good times and times to avoid, observances and details (Premium).
class PanchangDailyView extends StatelessWidget {
  const PanchangDailyView({super.key, required this.day, required this.terms});
  final PanchangDay day;
  final PanchangTerms terms;

  @override
  Widget build(BuildContext context) {
    final language = _lang(context);
    final premium = context.select<PremiumService?, bool>(
      (s) => s?.isPremium ?? false,
    );
    String time(DateTime? instant) =>
        PanchangFormat.time(instant, day.city, day.date, language);
    String? until(DateTime? instant) =>
        instant == null ? null : _t(context, 'panchang_until', [time(instant)]);
    final majors = day.observances.where((o) => o.isMajor).take(3);
    return Column(
      children: [
        PanchangPanel(
          key: const Key('panchang_daily_overview'),
          tint: PanchangColors.teal,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  context,
                  day.sunriseUtc == null
                      ? 'panchang_tithi_at_six'
                      : 'panchang_tithi_at_sunrise',
                ).toUpperCase(),
                style: const TextStyle(
                  color: PanchangColors.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                terms.tithi(day.tithi.paksha, day.tithi.name, language),
                key: const Key('panchang_tithi_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (until(day.tithi.endsAtUtc) case final text?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PanchangPill(
                    text:
                        '${terms.month(day.amantaMonth, language)} · ${_t(context, 'panchang_amanta')}',
                    color: PanchangColors.teal,
                    icon: Icons.dark_mode_outlined,
                  ),
                  PanchangPill(
                    text: terms.translate(
                      day.vara,
                      PanchangTermKind.vara,
                      language,
                    ),
                    color: PanchangColors.teal,
                    icon: Icons.calendar_today,
                  ),
                  for (final event in majors)
                    PanchangPill(
                      text: terms.observanceName(event, language),
                      color: Color(SearchCategory.festival.color),
                      icon: Icons.auto_awesome,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sunAndMoon(context, time),
        const SizedBox(height: 16),
        if (premium) ...[
          _limbs(context, language, until),
          const SizedBox(height: 16),
          _timings(context, language),
          if (day.observances.isNotEmpty) ...[
            const SizedBox(height: 16),
            PanchangCard(
              title: _t(context, 'panchang_observances'),
              icon: Icons.auto_awesome,
              children: [
                for (final event in day.observances)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          event.isMajor ? Icons.star : Icons.circle,
                          size: event.isMajor ? 16 : 8,
                          color: PanchangColors.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            terms.observanceName(event, language),
                            style: TextStyle(
                              fontWeight: event.isMajor
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _details(context, language, until),
        ] else
          const PanchangUpgradeCard(),
      ],
    );
  }

  Widget _sunAndMoon(BuildContext context, String Function(DateTime?) time) {
    final tiles = [
      (Icons.wb_sunny_outlined, 'panchang_sunrise', day.sunriseUtc),
      (Icons.wb_twilight, 'panchang_sunset', day.sunsetUtc),
      (Icons.nightlight_outlined, 'panchang_moonrise', day.moonriseUtc),
      (Icons.mode_night_outlined, 'panchang_moonset', day.moonsetUtc),
    ];
    Widget tile((IconData, String, DateTime?) data) {
      final (icon, key, instant) = data;
      return PanchangPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: PanchangColors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _t(context, key),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                time(instant),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('panchang_sun_moon'),
      children: [
        for (final pair in [tiles.sublist(0, 2), tiles.sublist(2)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(pair[0])),
                  const SizedBox(width: 10),
                  Expanded(child: tile(pair[1])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _limbs(
    BuildContext context,
    String language,
    String? Function(DateTime?) until,
  ) {
    final rows = [
      (
        'panchang_tithi',
        terms.tithi(day.tithi.paksha, day.tithi.name, language),
        until(day.tithi.endsAtUtc),
      ),
      (
        'panchang_nakshatra',
        terms.translate(
          day.nakshatra.name,
          PanchangTermKind.nakshatra,
          language,
        ),
        until(day.nakshatra.endsAtUtc),
      ),
      (
        'panchang_yoga',
        terms.translate(day.yoga.name, PanchangTermKind.yoga, language),
        until(day.yoga.endsAtUtc),
      ),
      (
        'panchang_karana',
        terms.translate(day.karana.name, PanchangTermKind.karana, language),
        until(day.karana.endsAtUtc),
      ),
      (
        'panchang_vara',
        terms.translate(day.vara, PanchangTermKind.vara, language),
        null,
      ),
    ];
    return PanchangCard(
      key: const Key('panchang_limbs'),
      title: _t(context, 'panchang_five_limbs'),
      icon: Icons.hexagon_outlined,
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const Divider(height: 1),
          PanchangValueRow(
            label: _t(context, row.$1),
            value: row.$2,
            detail: row.$3,
          ),
        ],
      ],
    );
  }

  Widget _timings(BuildContext context, String language) {
    final extra = day.additionalPeriods;
    final good = [
      ?day.brahmaMuhurta,
      ?day.abhijit,
      ...extra.where((p) => p.name == 'Amrit Kalam'),
    ]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final avoid = [
      ?day.rahukala,
      ?day.yamaganda,
      ?day.gulika,
      ...extra.where((p) => p.name != 'Amrit Kalam'),
    ]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    Widget row(PanchangPeriod p, Color color) => PanchangValueRow(
      label: terms.period(p.name, language),
      value: PanchangFormat.range(
        p.startUtc,
        p.endUtc,
        day.city,
        day.date,
        language,
      ),
      color: color,
    );
    return PanchangCard(
      key: const Key('panchang_timings'),
      title: _t(context, 'panchang_timings'),
      icon: Icons.schedule,
      children: [
        Text(
          _t(context, 'panchang_good_times'),
          style: const TextStyle(
            color: PanchangColors.good,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final p in good) row(p, PanchangColors.good),
        const Divider(),
        Text(
          _t(context, 'panchang_avoid_times'),
          style: const TextStyle(
            color: PanchangColors.avoid,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final p in avoid) row(p, PanchangColors.avoid),
      ],
    );
  }

  Widget _details(
    BuildContext context,
    String language,
    String? Function(DateTime?) until,
  ) {
    String limbName(String kind, PanchangLimb limb) => switch (kind) {
      'Tithi' => terms.tithi(limb.paksha, limb.name, language),
      'Nakshatra' => terms.translate(
        limb.name,
        PanchangTermKind.nakshatra,
        language,
      ),
      'Yoga' => terms.translate(limb.name, PanchangTermKind.yoga, language),
      'Karana' => terms.translate(limb.name, PanchangTermKind.karana, language),
      _ => limb.name,
    };
    return PanchangPanel(
      key: const Key('panchang_more_details'),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.list_alt, color: PanchangColors.teal),
          title: Text(
            _t(context, 'panchang_more_details'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            PanchangValueRow(
              label: _t(context, 'panchang_amanta'),
              value: terms.month(day.amantaMonth, language),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_purnimanta'),
              value: terms.month(day.purnimantaMonth, language),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_sun_rashi'),
              value: terms.translate(
                day.sunRashi,
                PanchangTermKind.rashi,
                language,
              ),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_moon_rashi'),
              value: terms.translate(
                day.moonRashi,
                PanchangTermKind.rashi,
                language,
              ),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_nakshatra_pada'),
              value: '${day.nakshatraPada}',
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_ritu'),
              value: terms.translate(day.ritu, PanchangTermKind.ritu, language),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_ayana'),
              value: terms.translate(
                day.ayana,
                PanchangTermKind.ayana,
                language,
              ),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_samvat'),
              value: _t(context, 'panchang_samvat_value', [
                '${day.shakaYear}',
                '${day.vikramaYear}',
              ]),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_anandadi'),
              value: terms.translate(
                day.anandadiYoga,
                PanchangTermKind.anandadi,
                language,
              ),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_special_yogas'),
              value: day.specialYogas.isEmpty
                  ? _t(context, 'panchang_none')
                  : day.specialYogas
                        .map(
                          (y) => terms.translate(
                            y,
                            PanchangTermKind.specialYoga,
                            language,
                          ),
                        )
                        .join(', '),
            ),
            PanchangValueRow(
              label: _t(context, 'panchang_ayanamsa'),
              value: '${day.ayanamsa.toStringAsFixed(4)}°',
            ),
            if (day.sunriseUtc == null || day.sunsetUtc == null)
              Text(
                _t(context, 'panchang_no_solar_day'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _t(context, 'panchang_transitions'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final entry in day.limbTimeline.entries)
              for (final limb in entry.value)
                PanchangValueRow(
                  label: _t(context, 'panchang_${entry.key.toLowerCase()}'),
                  value: limbName(entry.key, limb),
                  detail: until(limb.endsAtUtc),
                ),
          ],
        ),
      ),
    );
  }
}

// MARK: Muhurta

/// Choghadiya and Hora by day or night, and Udaya Lagna (Premium).
class PanchangMuhurtaView extends StatefulWidget {
  const PanchangMuhurtaView({
    super.key,
    required this.day,
    required this.terms,
  });
  final PanchangDay day;
  final PanchangTerms terms;

  @override
  State<PanchangMuhurtaView> createState() => _PanchangMuhurtaViewState();
}

class _PanchangMuhurtaViewState extends State<PanchangMuhurtaView> {
  bool _night = false;

  @override
  Widget build(BuildContext context) {
    final language = _lang(context);
    final day = widget.day, terms = widget.terms;
    final choghadiya = day.choghadiya
        .where((p) => p.name.startsWith(_night ? 'Night' : 'Day'))
        .toList();
    final hora = [
      for (final (i, p) in day.hora.indexed)
        if (_night ? i >= 12 : i < 12) p,
    ];
    final now = DateTime.now().toUtc();
    Widget row(
      String name,
      PanchangTermKind kind,
      PanchangPeriod p, [
      Color? color,
    ]) {
      final current = !now.isBefore(p.startUtc) && now.isBefore(p.endUtc);
      return PanchangValueRow(
        label: terms.translate(name, kind, language),
        value: PanchangFormat.range(
          p.startUtc,
          p.endUtc,
          day.city,
          day.date,
          language,
        ),
        color: color,
        trailing: current
            ? PanchangPill(
                text: _t(context, 'panchang_now'),
                color: PanchangColors.teal,
              )
            : null,
      );
    }

    Color quality(String name) {
      if (['Amrit', 'Shubh', 'Labh'].any(name.endsWith))
        return PanchangColors.good;
      if (name.endsWith('Chal')) return Colors.grey;
      return PanchangColors.avoid;
    }

    Widget unavailable() => Text(
      _t(context, 'panchang_unavailable'),
      style: Theme.of(context).textTheme.bodySmall,
    );

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            key: const Key('panchang_day_night'),
            segments: [
              ButtonSegment(
                value: false,
                label: Text(_t(context, 'panchang_day')),
              ),
              ButtonSegment(
                value: true,
                label: Text(_t(context, 'panchang_night')),
              ),
            ],
            selected: {_night},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _night = value.first),
          ),
        ),
        const SizedBox(height: 16),
        PanchangCard(
          title: _t(context, 'panchang_choghadiya'),
          icon: Icons.grid_view,
          children: [
            Text(
              _t(context, 'panchang_choghadiya_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (choghadiya.isEmpty) unavailable(),
            for (final p in choghadiya)
              row(
                p.name.split('·').last.trim(),
                PanchangTermKind.choghadiya,
                p,
                quality(p.name),
              ),
          ],
        ),
        const SizedBox(height: 16),
        PanchangCard(
          title: _t(context, 'panchang_hora'),
          icon: Icons.av_timer,
          children: [
            if (hora.isEmpty) unavailable(),
            for (final p in hora) row(p.name, PanchangTermKind.hora, p),
          ],
        ),
        const SizedBox(height: 16),
        PanchangCard(
          title: _t(context, 'panchang_lagna'),
          icon: Icons.public,
          children: [
            if (day.lagna.isEmpty) unavailable(),
            for (final p in day.lagna) row(p.name, PanchangTermKind.rashi, p),
          ],
        ),
      ],
    );
  }
}

// MARK: Rashi

class PanchangRashiView extends StatelessWidget {
  const PanchangRashiView({super.key, required this.day, required this.terms});
  final PanchangDay day;
  final PanchangTerms terms;

  @override
  Widget build(BuildContext context) {
    final language = _lang(context);
    String? until(DateTime? instant) => instant == null
        ? null
        : _t(context, 'panchang_until', [
            PanchangFormat.time(instant, day.city, day.date, language),
          ]);
    return Column(
      children: [
        PanchangCard(
          title: _t(context, 'panchang_sun_rashi'),
          icon: Icons.wb_sunny,
          children: [
            PanchangValueRow(
              label: _t(context, 'panchang_rashi'),
              value: terms.translate(
                day.sunRashi,
                PanchangTermKind.rashi,
                language,
              ),
              detail: until(day.sunRashiEndsAtUtc),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PanchangCard(
          title: _t(context, 'panchang_moon_rashi'),
          icon: Icons.nightlight,
          children: [
            PanchangValueRow(
              label: _t(context, 'panchang_rashi'),
              value: terms.translate(
                day.moonRashi,
                PanchangTermKind.rashi,
                language,
              ),
              detail: until(day.moonRashiEndsAtUtc),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PanchangCard(
          title: _t(context, 'panchang_nakshatra'),
          icon: Icons.star,
          children: [
            PanchangValueRow(
              label: _t(context, 'panchang_nakshatra'),
              value: terms.translate(
                day.nakshatra.name,
                PanchangTermKind.nakshatra,
                language,
              ),
              detail: until(day.nakshatra.endsAtUtc),
            ),
            const Divider(height: 1),
            PanchangValueRow(
              label: _t(context, 'panchang_nakshatra_pada'),
              value: '${day.nakshatraPada}',
              detail: until(day.padaEndsAtUtc),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _t(context, 'panchang_rashi_note'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// MARK: Ekadashi

/// Calculated Smarta or Gaudiya/ISKCON fasts for the month and location, in
/// the app language. A preview: the published schedule still drives the
/// calendar, reminders and Journey.
class PanchangEkadashiView extends StatefulWidget {
  const PanchangEkadashiView({
    super.key,
    required this.month,
    required this.city,
    required this.tradition,
    required this.onTraditionChanged,
    required this.terms,
  });
  final DateTime month;
  final PanchangCity city;
  final EkadashiTradition tradition;
  final ValueChanged<EkadashiTradition> onTraditionChanged;
  final PanchangTerms terms;

  @override
  State<PanchangEkadashiView> createState() => _PanchangEkadashiViewState();
}

class _PanchangEkadashiViewState extends State<PanchangEkadashiView> {
  List<CalculatedEkadashi>? _fasts;
  bool _failed = false;
  String _loadedKey = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PanchangEkadashiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load({bool retry = false}) async {
    final month = widget.month,
        city = widget.city,
        tradition = widget.tradition;
    final key =
        '${month.year}-${month.month}|${city.id}|${city.latitude}|${city.longitude}|${city.timeZoneId}|${tradition.name}';
    if (key == _loadedKey && !retry) return;
    _loadedKey = key;
    setState(() {
      _fasts = null;
      _failed = false;
    });
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    List<CalculatedEkadashi> calculate() =>
        const CalculatedEkadashiEngine().calculate(
          DateTime.utc(month.year, month.month, 1),
          days,
          city,
          tradition,
        );
    try {
      final result = ObservanceCalendarService.calculateInline
          ? calculate()
          : await Isolate.run(calculate);
      if (!mounted || key != _loadedKey) return;
      setState(() => _fasts = result);
    } catch (_) {
      if (!mounted || key != _loadedKey) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = _lang(context);
    final fasts = _fasts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final item in EkadashiTradition.values)
              ChoiceChip(
                key: Key('panchang_tradition_${item.name}'),
                label: Text(
                  _t(
                    context,
                    item == EkadashiTradition.smarta
                        ? 'panchang_smarta'
                        : 'panchang_gaudiya',
                  ),
                ),
                selected: widget.tradition == item,
                showCheckmark: false,
                selectedColor: PanchangColors.teal.withValues(alpha: .18),
                shape: const StadiumBorder(),
                onSelected: (_) => widget.onTraditionChanged(item),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            context,
            widget.tradition == EkadashiTradition.smarta
                ? 'panchang_smarta_rule'
                : 'panchang_gaudiya_rule',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_failed)
          Center(
            child: Column(
              children: [
                Text(_t(context, 'panchang_calculation_failed')),
                TextButton(
                  onPressed: () => _load(retry: true),
                  child: Text(_t(context, 'retry')),
                ),
              ],
            ),
          )
        else if (fasts == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: PanchangColors.teal),
            ),
          )
        else if (fasts.isEmpty)
          Text(
            _t(context, 'panchang_no_calculated_fast'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final fast in fasts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(context, fast, language),
            ),
        Text(
          _t(context, 'panchang_calculated_preview'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _card(BuildContext context, CalculatedEkadashi fast, String language) {
    final terms = widget.terms;
    String time(DateTime? instant, DateTime date) =>
        PanchangFormat.time(instant, widget.city, date, language);
    final parana = fast.paranaStartUtc == null
        ? _t(context, 'panchang_unavailable')
        : fast.paranaEndUtc == null
        ? _t(context, 'panchang_after', [
            time(fast.paranaStartUtc, fast.paranaDate),
          ])
        : '${time(fast.paranaStartUtc, fast.paranaDate)} – ${time(fast.paranaEndUtc, fast.paranaDate)}';
    return PanchangPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            terms.translate(fast.name, PanchangTermKind.ekadashiName, language),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          PanchangValueRow(
            label: _t(context, 'panchang_fast_day'),
            value: PanchangFormat.date(fast.date, language),
            detail: _t(context, 'panchang_starts_at', [
              time(fast.fastStartsUtc, fast.date),
            ]),
          ),
          PanchangValueRow(
            label: _t(context, 'panchang_parana'),
            value: PanchangFormat.date(fast.paranaDate, language),
            detail: parana,
          ),
          if (fast.nearBoundary)
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _t(context, 'panchang_near_boundary'),
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                _t(context, 'panchang_calculation_details'),
                style: const TextStyle(fontSize: 14),
              ),
              children: [
                PanchangValueRow(
                  label: _t(context, 'panchang_rule'),
                  value: terms.ekadashiNote(fast.rule, language),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    terms.ekadashiNote(fast.paranaReason, language),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                PanchangValueRow(
                  label: _t(context, 'panchang_tithi'),
                  value:
                      '${time(fast.tithiStartUtc, fast.date)} – ${time(fast.tithiEndUtc, fast.date)}',
                ),
                PanchangValueRow(
                  label: _t(context, 'panchang_hari_vasara_ends'),
                  value: time(fast.hariVasaraEndUtc, fast.paranaDate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
