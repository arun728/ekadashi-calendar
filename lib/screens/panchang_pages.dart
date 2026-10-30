import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/panchang/calculated_ekadashi.dart';
import '../services/panchang/observance_calendar_service.dart';
import '../services/panchang/panchang_data_service.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_key_days.dart';
import '../services/panchang/panchang_models.dart';
import '../services/panchang/panchang_terms.dart';
import '../services/premium_service.dart';
import '../services/search/search_catalog.dart';
import '../widgets/ios_style.dart';
import 'global_search_screen.dart' show searchCategoryIcon;
import 'premium_screen.dart';
import '../widgets/app_icons.dart';

/// Colours shared by the Panchang pages (the iOS Theme: teal, amber,
/// Theme.missed; good is Theme.observed, SwiftUI .green, see [good]).
abstract final class PanchangColors {
  static const teal = IosColors.teal;
  static const avoid = IosColors.missed;
  static const amber = IosColors.amber;

  /// Theme.observed (the system green, lighter in dark mode).
  static Color good(BuildContext context) => IosColors.green(context);
}

String _lang(BuildContext context) =>
    context.watch<LanguageService>().currentLocale.languageCode;

String _t(BuildContext context, String key, [List<String> args = const []]) =>
    AppStrings.translateWithArgs(key, _lang(context), args);

/// The iOS hairline Divider.
Widget _divider(BuildContext context) =>
    Divider(height: 1, thickness: .5, color: IosColors.separator(context));

/// SwiftUI VStack spacing: [gap] between the children.
List<Widget> _spaced(Iterable<Widget> children, double gap) => [
  for (final (index, child) in children.indexed) ...[
    if (index > 0) SizedBox(height: gap),
    child,
  ],
];

TextStyle _secondary(BuildContext context, double size) =>
    TextStyle(fontSize: size, color: IosColors.secondary(context));

/// A titled glass card (iOS PanchangCard): radius 20, padding 16, a teal
/// symbol and a headline title, 12 between every child.
class PanchangCard extends StatelessWidget {
  const PanchangCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });
  final String title;
  final Widget? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PanchangPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        Row(
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: const IconThemeData(size: 18, color: IosColors.teal),
                child: icon!,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: IosText.headline,
                  fontWeight: FontWeight.w600,
                  color: IosColors.primary(context),
                ),
              ),
            ),
          ],
        ),
        ...children,
      ], 12),
    ),
  );
}

/// A full-width glass panel (Glass.swift glassPanel).
class PanchangPanel extends StatelessWidget {
  const PanchangPanel({
    super.key,
    required this.child,
    this.tint,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final Color? tint;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GlassPanel(
      radius: radius,
      tint: tint,
      padding: padding,
      onTap: onTap,
      child: child,
    ),
  );
}

/// A label on the left and a value (with an optional detail) on the right
/// (iOS PanchangRow): subheadline label in grey, subheadline semibold value
/// and a caption detail. Like a SwiftUI HStack, the shorter side keeps its
/// natural width and the longer one takes the rest.
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

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = _secondary(context, IosText.subheadline);
    final valueStyle = TextStyle(
      fontSize: IosText.subheadline,
      fontWeight: FontWeight.w600,
      color: IosColors.primary(context),
    );
    final detailStyle = _secondary(context, IosText.caption);
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width.ceilToDouble() + 1;
    }

    final row = LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _gap;
        final labelWidth = measure(label, labelStyle);
        final valueWidth = math.max(
          measure(value, valueStyle),
          detail == null ? 0.0 : measure(detail!, detailStyle),
        );
        final half = available / 2;
        final double valueSlot;
        if (labelWidth + valueWidth <= available || valueWidth <= half) {
          valueSlot = math.min(valueWidth, available);
        } else if (labelWidth <= half) {
          valueSlot = available - labelWidth;
        } else {
          valueSlot = half;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            const SizedBox(width: _gap),
            SizedBox(
              width: math.max(0, valueSlot),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, textAlign: TextAlign.end, style: valueStyle),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, textAlign: TextAlign.end, style: detailStyle),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (color != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          Expanded(child: row),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A tappable disclosure row like SwiftUI's DisclosureGroup: the label,
/// then a teal chevron that turns down when open.
class _Disclosure extends StatefulWidget {
  const _Disclosure({
    required this.label,
    required this.children,
    this.spacing = 10,
    this.topPadding = 10,
  });
  final Widget label;
  final List<Widget> children;
  final double spacing;
  final double topPadding;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        button: true,
        expanded: _open,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Expanded(child: widget.label),
              AnimatedRotation(
                turns: _open ? .25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  AppIcons.rowDisclosure,
                  size: 20,
                  color: IosColors.teal,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_open)
        Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(widget.children, widget.spacing),
          ),
        ),
    ],
  );
}

/// The paywall card for Premium Panchang sections (iOS PanchangUpgradeCard:
/// radius 22, padding 18, teal tint, the prominent capsule).
class PanchangUpgradeCard extends StatelessWidget {
  const PanchangUpgradeCard({super.key});

  @override
  Widget build(BuildContext context) => PanchangPanel(
    tint: PanchangColors.teal,
    radius: 22,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(AppIcons.lock, color: PanchangColors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(context, 'panchang_premium_title'),
                style: const TextStyle(
                  color: PanchangColors.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: IosText.headline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _t(context, 'panchang_premium_body'),
          style: _secondary(context, IosText.subheadline),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('panchang_unlock_button'),
            style: IosButtons.prominent(),
            onPressed: () => openPremium(context),
            icon: const Icon(AppIcons.panchangUnlock, size: 18),
            label: Text(
              _t(context, 'panchang_unlock'),
              style: IosButtons.label,
            ),
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
        '${widget.month.year}-${widget.month.month}|${widget.city.id}|${widget.city.latitude}|${widget.city.longitude}|${widget.city.timeZoneId}';
    if (key == _loadedKey) return;
    _loadedKey = key;
    final month = widget.month, city = widget.city;
    final cached = ObservanceCalendarService.instance.cachedMonth(month, city);
    setState(() => _observances = cached);
    final catalog = await SearchCatalog.load();
    final observances =
        cached ?? await ObservanceCalendarService.instance.month(month, city);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        SingleChildScrollView(
          key: const Key('panchang_key_day_filters'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              _chip(context, null),
              for (final type in _filters) ...[
                const SizedBox(width: 8),
                _chip(context, type),
              ],
            ],
          ),
        ),
        if (!premium) _lockedBanner(context),
        if (days == null)
          const SizedBox(
            height: 160,
            child: Center(
              child: CircularProgressIndicator(color: PanchangColors.teal),
            ),
          )
        else if (days.isEmpty)
          SizedBox(
            height: 120,
            child: Center(
              child: Text(
                _t(context, 'panchang_no_key_days'),
                textAlign: TextAlign.center,
                style: _secondary(context, IosText.subheadline),
              ),
            ),
          )
        else
          Column(
            key: const Key('panchang_key_days'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced([
              for (final day in days) _row(context, day, premium, language),
            ], 10),
          ),
      ], 12),
    );
  }

  /// iOS: the lock, the note and the filled prominent "Unlock" beside it.
  Widget _lockedBanner(BuildContext context) => PanchangPanel(
    tint: PanchangColors.amber,
    radius: 18,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        const Icon(AppIcons.lock, color: PanchangColors.amber, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _t(context, 'panchang_key_days_locked'),
            style: TextStyle(
              fontSize: IosText.subheadline,
              color: IosColors.primary(context),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Long words at large text sizes shrink rather than overflow.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: FilledButton(
            key: const Key('panchang_key_days_unlock'),
            style: IosButtons.prominent(vertical: 7).copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
            ),
            onPressed: () => openPremium(context),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _t(context, 'panchang_unlock_short'),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: IosText.subheadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chip(BuildContext context, SearchCategory? type) {
    final selected = _category == type;
    return GlassChip(
      key: Key('panchang_key_filter_${type?.raw ?? 'all'}'),
      label: _t(context, type == null ? 'filter_all' : type.localizationKey),
      icon: type == null ? null : searchCategoryIcon(type),
      color: type == null ? PanchangColors.teal : Color(type.color),
      selected: selected,
      onTap: () =>
          setState(() => _category = selected || type == null ? null : type),
    );
  }

  Widget _row(BuildContext context, KeyDay day, bool premium, String language) {
    final type = day.categories.contains(SearchCategory.festival)
        ? SearchCategory.festival
        : day.categories.firstOrNull ?? SearchCategory.festival;
    final color = Color(type.color);
    final locked = day.requiresPremium && !premium;
    final secondary = IosColors.secondary(context);
    return PanchangPanel(
      key: Key('panchang_key_day_${day.id}'),
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: () => locked ? openPremium(context) : widget.onOpen(day.date),
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
                ? const Icon(
                    AppIcons.lock,
                    color: PanchangColors.amber,
                    size: IosText.title3,
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.date.day}',
                          style: TextStyle(
                            fontSize: IosText.title2,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: IosColors.primary(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          PanchangFormat.weekday(day.date, language),
                          style: TextStyle(
                            fontSize: IosText.caption2,
                            fontWeight: FontWeight.w600,
                            color: secondary,
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
                  style: TextStyle(
                    fontSize: IosText.headline,
                    fontWeight: FontWeight.w600,
                    color: IosColors.primary(context),
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
                        TextSpan(text: '  ·  ${_countdown(context, day.date)}'),
                    ],
                  ),
                  style: TextStyle(fontSize: IosText.caption, color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            locked ? AppIcons.lock : AppIcons.rowDisclosure,
            size: locked ? 14 : 18,
            color: locked ? PanchangColors.amber : secondary,
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        _hero(context, language, until),
        _sunAndMoon(context, time),
        if (premium) ...[
          _limbs(context, language, until),
          _timings(context, language),
          if (day.observances.isNotEmpty) _observances(context, language),
          _details(context, language, until),
        ] else
          const PanchangUpgradeCard(),
      ], 16),
    );
  }

  /// iOS hero: radius 24, teal tint, caption2 heading, title tithi and
  /// status pills.
  Widget _hero(
    BuildContext context,
    String language,
    String? Function(DateTime?) until,
  ) {
    final majors = day.observances.where((o) => o.isMajor).take(3);
    return GlassPanel(
      key: const Key('panchang_daily_overview'),
      tint: PanchangColors.teal,
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _spaced([
          Text(
            _t(
              context,
              day.sunriseUtc == null
                  ? 'panchang_tithi_at_six'
                  : 'panchang_tithi_at_sunrise',
            ).toUpperCase(),
            style: const TextStyle(
              color: PanchangColors.teal,
              fontSize: IosText.caption2,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            terms.tithi(day.tithi.paksha, day.tithi.name, language),
            key: const Key('panchang_tithi_title'),
            style: TextStyle(
              fontSize: IosText.title,
              fontWeight: FontWeight.w700,
              color: IosColors.primary(context),
            ),
          ),
          if (until(day.tithi.endsAtUtc) case final text?)
            Text(text, style: _secondary(context, IosText.subheadline)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                text:
                    '${terms.month(day.amantaMonth, language)} · ${_t(context, 'panchang_amanta')}',
                color: PanchangColors.teal,
                icon: AppIcons.panchangTithi,
              ),
              StatusPill(
                text: terms.translate(
                  day.vara,
                  PanchangTermKind.vara,
                  language,
                ),
                color: PanchangColors.teal,
                icon: AppIcons.panchangVara,
              ),
              for (final event in majors)
                StatusPill(
                  text: terms.observanceName(event, language),
                  color: Color(SearchCategory.festival.color),
                  icon: AppIcons.panchangObservance,
                ),
            ],
          ),
        ], 10),
      ),
    );
  }

  /// Sunrise, sunset, moonrise and moonset: iOS multicolour symbols (a
  /// yellow sun or grey moon on the horizon with a rising or setting
  /// arrow) in glass tiles, radius 18.
  Widget _sunAndMoon(BuildContext context, String Function(DateTime?) time) {
    final tiles = [
      (true, AppIcons.sunrise, 'panchang_sunrise', day.sunriseUtc),
      (true, AppIcons.sunset, 'panchang_sunset', day.sunsetUtc),
      (false, AppIcons.moonrise, 'panchang_moonrise', day.moonriseUtc),
      (false, AppIcons.moonset, 'panchang_moonset', day.moonsetUtc),
    ];
    final secondary = IosColors.secondary(context);
    Widget tile((bool, IconData, String, DateTime?) data) {
      final (sun, icon, key, instant) = data;
      return PanchangPanel(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  key: Key('${key}_icon'),
                  size: 16,
                  color: sun ? IosColors.yellow(context) : secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _t(context, key),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: IosText.caption,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                time(instant),
                maxLines: 1,
                style: TextStyle(
                  fontSize: IosText.headline,
                  fontWeight: FontWeight.w600,
                  color: IosColors.primary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('panchang_sun_moon'),
      children: _spaced([
        for (final pair in [tiles.sublist(0, 2), tiles.sublist(2)])
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(pair[0])),
                const SizedBox(width: 10),
                Expanded(child: tile(pair[1])),
              ],
            ),
          ),
      ], 10),
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
    // circle.hexagongrid
    return PanchangCard(
      key: const Key('panchang_limbs'),
      title: _t(context, 'panchang_five_limbs'),
      icon: const Icon(AppIcons.fiveLimbs),
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) _divider(context),
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
    final goodColor = PanchangColors.good(context);
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
    Widget heading(String key, Color color) => Text(
      _t(context, key),
      style: TextStyle(
        color: color,
        fontSize: IosText.caption,
        fontWeight: FontWeight.w700,
      ),
    );
    return PanchangCard(
      key: const Key('panchang_timings'),
      title: _t(context, 'panchang_timings'),
      icon: const Icon(AppIcons.timings),
      children: [
        heading('panchang_good_times', goodColor),
        for (final p in good) row(p, goodColor),
        _divider(context),
        heading('panchang_avoid_times', PanchangColors.avoid),
        for (final p in avoid) row(p, PanchangColors.avoid),
      ],
    );
  }

  /// iOS: a sparkle (four-point star) for major observances and a small
  /// dot for the others, in the primary colour.
  Widget _observances(BuildContext context, String language) {
    final primary = IosColors.primary(context);
    return PanchangCard(
      key: const Key('panchang_observances'),
      title: _t(context, 'panchang_observances'),
      icon: const Icon(AppIcons.observances),
      children: [
        for (final event in day.observances)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: event.isMajor
                      ? Icon(
                          AppIcons.observanceMajor,
                          key: const Key('panchang_sparkle'),
                          size: 15,
                          color: primary,
                        )
                      : Icon(AppIcons.observanceMinor, size: 7, color: primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  terms.observanceName(event, language),
                  style: TextStyle(
                    fontSize: IosText.subheadline,
                    color: primary,
                    fontWeight: event.isMajor
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
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
      child: _Disclosure(
        label: Row(
          children: [
            const Icon(
              AppIcons.moreDetails,
              size: 18,
              color: PanchangColors.teal,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(context, 'panchang_more_details'),
                style: TextStyle(
                  fontSize: IosText.headline,
                  fontWeight: FontWeight.w600,
                  color: IosColors.primary(context),
                ),
              ),
            ),
          ],
        ),
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
            value: terms.translate(day.ayana, PanchangTermKind.ayana, language),
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
          if (day.sunriseUtc == null || day.sunsetUtc == null)
            Text(
              _t(context, 'panchang_no_solar_day'),
              style: _secondary(context, IosText.caption),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _divider(context),
          ),
          Text(
            _t(context, 'panchang_transitions'),
            style: TextStyle(
              fontSize: IosText.subheadline,
              fontWeight: FontWeight.w600,
              color: IosColors.primary(context),
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
            ? StatusPill(
                text: _t(context, 'panchang_now'),
                color: PanchangColors.teal,
              )
            : null,
      );
    }

    /// Amrit, Shubh and Labh are favourable; Chal neutral; the others not.
    Color quality(String name) {
      if (['Amrit', 'Shubh', 'Labh'].any(name.endsWith)) {
        return PanchangColors.good(context);
      }
      if (name.endsWith('Chal')) return IosColors.gray(context);
      return PanchangColors.avoid;
    }

    Widget unavailable() => Text(
      _t(context, 'panchang_unavailable'),
      style: _secondary(context, IosText.subheadline),
    );

    Widget segment(String key) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        _t(context, key),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: IosColors.primary(context),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        // iOS Picker(.segmented).
        CupertinoSlidingSegmentedControl<bool>(
          key: const Key('panchang_day_night'),
          groupValue: _night,
          children: {
            false: segment('panchang_day'),
            true: segment('panchang_night'),
          },
          onValueChanged: (value) {
            if (value != null) setState(() => _night = value);
          },
        ),
        PanchangCard(
          title: _t(context, 'panchang_choghadiya'),
          icon: const Icon(AppIcons.choghadiya, key: Key('panchang_dot_grid')),
          children: [
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
        PanchangCard(
          title: _t(context, 'panchang_hora'),
          icon: const Icon(AppIcons.hora),
          children: [
            if (hora.isEmpty) unavailable(),
            for (final p in hora) row(p.name, PanchangTermKind.hora, p),
          ],
        ),
        PanchangCard(
          title: _t(context, 'panchang_lagna'),
          icon: const Icon(AppIcons.lagna),
          children: [
            if (day.lagna.isEmpty) unavailable(),
            for (final p in day.lagna) row(p.name, PanchangTermKind.rashi, p),
          ],
        ),
      ], 16),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        PanchangCard(
          title: _t(context, 'panchang_sun_rashi'),
          icon: const Icon(AppIcons.sunRashi),
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
        PanchangCard(
          title: _t(context, 'panchang_moon_rashi'),
          icon: const Icon(AppIcons.moonRashi),
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
        PanchangCard(
          title: _t(context, 'panchang_nakshatra'),
          icon: const Icon(AppIcons.nakshatra),
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
            _divider(context),
            PanchangValueRow(
              label: _t(context, 'panchang_nakshatra_pada'),
              value: '${day.nakshatraPada}',
              detail: until(day.padaEndsAtUtc),
            ),
          ],
        ),
      ], 16),
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
    try {
      final result = await PanchangDataService.instance.fasts(
        month,
        city,
        tradition,
      );
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in EkadashiTradition.values)
              GlassChip(
                key: Key('panchang_tradition_${item.name}'),
                label: _t(
                  context,
                  // "Smarta" or "Vaishnava" everywhere.
                  item == EkadashiTradition.smarta
                      ? 'tradition_smarta'
                      : 'tradition_vaishnava',
                ),
                selected: widget.tradition == item,
                onTap: () => widget.onTraditionChanged(item),
              ),
          ],
        ),
        if (_failed)
          Column(
            children: [
              Text(
                _t(context, 'panchang_calculation_failed'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: IosText.body,
                  color: IosColors.primary(context),
                ),
              ),
              const SizedBox(height: 8),
              BarTextButton(
                label: _t(context, 'retry'),
                onPressed: () => _load(retry: true),
              ),
            ],
          )
        else if (fasts == null)
          const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: PanchangColors.teal),
            ),
          )
        else if (fasts.isEmpty)
          Text(
            _t(context, 'panchang_no_calculated_fast'),
            style: _secondary(context, IosText.subheadline),
          )
        else
          for (final fast in fasts) _card(context, fast, language),
      ], 12),
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
    return KeyedSubtree(
      key: ValueKey('fast_${fast.date}_${fast.name}'),
      child: GlassPanel(
        key: const Key('panchang_fast_card'),
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced([
            Text(
              terms.translate(
                fast.name,
                PanchangTermKind.ekadashiName,
                language,
              ),
              style: TextStyle(
                fontSize: IosText.headline,
                fontWeight: FontWeight.w600,
                color: IosColors.primary(context),
              ),
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
            _Disclosure(
              spacing: 8,
              topPadding: 6,
              label: Text(
                _t(context, 'panchang_more_details'),
                style: TextStyle(
                  fontSize: IosText.subheadline,
                  color: IosColors.primary(context),
                ),
              ),
              children: [
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
          ], 10),
        ),
      ),
    );
  }
}
