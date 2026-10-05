import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_engine.dart';
import '../services/panchang/panchang_models.dart';
import '../services/premium_service.dart';
import 'premium_screen.dart';

class PanchangScreen extends StatefulWidget {
  const PanchangScreen({
    super.key,
    this.initialDate,
    this.initialCity = PanchangCity.newDelhi,
    this.engine = const PanchangEngine(),
  });

  final DateTime? initialDate;
  final PanchangCity initialCity;
  final PanchangEngine engine;

  @override
  State<PanchangScreen> createState() => _PanchangScreenState();
}

class _PanchangScreenState extends State<PanchangScreen> {
  late DateTime _date;
  late PanchangCity _city;
  late PanchangDay _day;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? _today();
    _date = DateTime.utc(now.year, now.month, now.day);
    _city = widget.initialCity;
    _recalculate();
  }

  void _recalculate() {
    _day = widget.engine.calculate(_date, city: _city);
  }

  void _changeDate(int offset) {
    setState(() {
      _date = _date.add(Duration(days: offset));
      _recalculate();
    });
  }

  void _changeCity(PanchangCity? city) {
    if (city == null || city == _city) return;
    setState(() {
      _city = city;
      _recalculate();
    });
  }

  DateTime _today() {
    final nowIst = DateTime.now().toUtc().add(istOffset);
    return DateTime.utc(nowIst.year, nowIst.month, nowIst.day);
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.select<PremiumService?, bool>(
      (service) => service?.isPremium ?? false,
    );
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const Key('panchang_scroll_view'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverList.list(
              children: [
                _buildHeader(context, colors),
                const SizedBox(height: 20),
                _buildHero(context, colors),
                const SizedBox(height: 18),
                if (premium) ...[
                  _buildLimbGrid(context, colors),
                  const SizedBox(height: 16),
                  _buildTimingPanel(context, colors),
                  const SizedBox(height: 16),
                  _buildObservances(context, colors),
                  const SizedBox(height: 16),
                  _buildTraditionNote(context, colors),
                ] else ...[
                  _buildFreeObservancePreview(context, colors),
                  const SizedBox(height: 16),
                  _buildUpgradeCard(context, colors),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colors) {
    final today = _today();
    final isToday =
        _date.year == today.year &&
        _date.month == today.month &&
        _date.day == today.day;
    final weekday = _weekday(_date.weekday);
    final dateLabel =
        '$weekday, ${_month(_date.month)} ${_date.day}, ${_date.year}';
    final title = Text(
      'Panchang',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
    final citySelector = Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PanchangCity>(
          key: const Key('panchang_city_selector'),
          value: _city,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(Icons.expand_more, size: 20),
          isExpanded: true,
          isDense: true,
          items: [
            for (final city in PanchangCity.supported)
              DropdownMenuItem(
                value: city,
                child: Text(city.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _changeCity,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 325 ||
                MediaQuery.textScalerOf(context).scale(14) > 17.5;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 8),
                  SizedBox(width: constraints.maxWidth, child: citySelector),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                SizedBox(width: 180, child: citySelector),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'IST · English',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.primary,
            letterSpacing: .35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                key: const Key('panchang_previous_day'),
                tooltip: 'Previous day',
                onPressed: () => _changeDate(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      dateLabel,
                      key: const Key('panchang_selected_date'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isToday)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _date = _today();
                            _recalculate();
                          });
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 25),
                        ),
                        child: const Text('Today'),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('panchang_next_day'),
                tooltip: 'Next day',
                onPressed: () => _changeDate(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context, ColorScheme colors) {
    final title = '${_day.tithi.paksha} ${_day.tithi.name}';
    return Container(
      key: const Key('panchang_daily_overview'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            Color.lerp(colors.primaryContainer, colors.surface, .42)!,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.primary.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(14) > 17.5;
              final labelText = Text(
                'TITHI AT SUNRISE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.25,
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimaryContainer.withValues(alpha: .78),
                ),
              );
              final icon = Icon(
                Icons.nightlight_round,
                color: colors.primary,
                size: 20,
              );
              final compactLabel = Row(
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Expanded(child: labelText),
                ],
              );
              final fullLabel = Row(
                mainAxisSize: MainAxisSize.min,
                children: [icon, const SizedBox(width: 8), labelText],
              );
              final month = Text(
                'Amanta · ${_day.amantaMonth}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [compactLabel, const SizedBox(height: 5), month],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [fullLabel, month],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            title,
            key: const Key('panchang_tithi_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -.35,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _day.tithi.endsAtUtc == null
                ? 'Tithi transition unavailable'
                : 'Changes at ${formatIstTime(_day.tithi.endsAtUtc)} IST',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: .8),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sunPill(
                context,
                icon: Icons.wb_sunny_outlined,
                label: 'Sunrise',
                value: formatIstTime(_day.sunriseUtc),
              ),
              _sunPill(
                context,
                icon: Icons.wb_twilight,
                label: 'Sunset',
                value: formatIstTime(_day.sunsetUtc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sunPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '$label  $value',
              softWrap: true,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimbGrid(BuildContext context, ColorScheme colors) {
    final limbs = [
      ('Tithi', '${_day.tithi.paksha} ${_day.tithi.name}', _day.tithi),
      ('Nakshatra', _day.nakshatra.name, _day.nakshatra),
      ('Yoga', _day.yoga.name, _day.yoga),
      ('Karana', _day.karana.name, _day.karana),
      ('Vara', _day.vara, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Five limbs', 'Panchang at local sunrise'),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 320 ? 1 : 2;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in limbs)
                  SizedBox(
                    width: itemWidth,
                    child: _limbCard(
                      context,
                      colors,
                      item.$1,
                      item.$2,
                      item.$3?.endsAtUtc,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _limbCard(
    BuildContext context,
    ColorScheme colors,
    String label,
    String value,
    DateTime? end,
  ) => Container(
    decoration: BoxDecoration(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (end != null) ...[
          const SizedBox(height: 4),
          Text(
            'Until ${formatIstTime(end)} IST',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    ),
  );

  Widget _buildTimingPanel(BuildContext context, ColorScheme colors) {
    return _surfacePanel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Daily timings', _city.label),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.brightness_3_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 9),
              const Expanded(child: Text('Lunar month labels')),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Amanta · ${_day.amantaMonth}'),
                  const SizedBox(height: 2),
                  Text(
                    'Purnimanta · ${_day.purnimantaMonth}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          for (final period in [_day.rahukala, _day.yamaganda, _day.gulika])
            if (period != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 17, color: colors.primary),
                    const SizedBox(width: 9),
                    Expanded(child: Text(period.name)),
                    Text(
                      '${formatIstTime(period.startUtc)} – ${formatIstTime(period.endUtc)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.nightlight_outlined, size: 18),
              const SizedBox(width: 9),
              const Expanded(child: Text('Moonrise')),
              Text(formatIstTime(_day.moonriseUtc)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObservances(BuildContext context, ColorScheme colors) {
    final events = _day.observances;
    return _surfacePanel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            context,
            'Observances',
            'Calculated for ${_city.label}',
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Text(
              'No supported observance rule matches this date.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          else
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      event.isMajor ? Icons.auto_awesome : Icons.circle,
                      size: event.isMajor ? 18 : 8,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (event.description.isNotEmpty)
                            Text(
                              event.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFreeObservancePreview(BuildContext context, ColorScheme colors) {
    final events = _day.observances
        .where((item) => item.isMajor)
        .take(2)
        .toList();
    return _surfacePanel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Today’s observances', 'A local preview'),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Text(
              'Explore the full Panchang for observances and daily timings.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          else
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 17, color: colors.primary),
                    const SizedBox(width: 9),
                    Expanded(child: Text(event.name)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(BuildContext context, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: .28)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: colors.primary),
              const SizedBox(width: 8),
              // Wraps at large text sizes instead of overflowing on phones.
              Expanded(
                child: Text(
                  'Full Panchang · Premium',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'See all five limbs, lunar transitions, observances and city-specific daily timings.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('panchang_unlock_button'),
              onPressed: () => openPremium(context, currentTimezone: 'IST'),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Unlock full Panchang'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraditionNote(
    BuildContext context,
    ColorScheme colors,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 17, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Festival dates follow the displayed sunrise, sunset or night rule. Regional and community traditions can differ; Amanta and Purnimanta month names are shown in the calculation notes.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );

  Widget _surfacePanel(BuildContext context, {required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .72)),
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  static String _weekday(int day) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][day - 1];

  static String _month(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}
