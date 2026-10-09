import 'package:flutter/material.dart';
import '../services/notifications/event_reminder_service.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/place_names.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../services/panchang/calculated_ekadashi.dart';
import '../services/panchang/panchang_city.dart';
import '../services/panchang/panchang_engine.dart';
import '../services/panchang/panchang_location_store.dart';
import '../services/panchang/panchang_models.dart';
import '../services/panchang/panchang_terms.dart';
import '../services/premium_service.dart';
import '../widgets/glass_tube.dart';
import '../widgets/section_pager.dart';
import 'panchang_location_dialog.dart';
import 'panchang_pages.dart';

/// The Panchang pages, in tab order.
enum PanchangPage {
  keyDays('keydays'),
  daily('daily'),
  muhurta('muhurta'),
  ekadashi('ekadashi'),
  rashi('rashi');

  const PanchangPage(this.raw);
  final String raw;

  String get titleKey => 'panchang_section_$raw';

  /// Pages that browse a month rather than a day.
  bool get isMonthly => this == keyDays || this == ekadashi;
}

/// Panchang (docs/ROADMAP.md Phases 2 and 3): calculated offline for any
/// location and date, in the app language. Key days (the month's
/// Ekadashis, Amavasya, Purnima, Shivaratri and festivals) comes first.
/// Free: published Ekadashis in Key days, the day's tithi, sun and moon
/// times, the day's festival names and the calculated Ekadashi list.
/// Premium: the other Key days, the five limbs, timings, Muhurta and Rashi.
/// The sections change with their chips or a horizontal swipe.
class PanchangScreen extends StatefulWidget {
  const PanchangScreen({
    super.key,
    this.initialDate,
    this.initialCity,
    this.ekadashiList = const [],
    this.engine = const PanchangEngine(),
  });

  final DateTime? initialDate;
  final PanchangCity? initialCity;

  /// The published schedule in the app language (Key days lists it).
  final List<EkadashiDate> ekadashiList;
  final PanchangEngine engine;

  @override
  State<PanchangScreen> createState() => PanchangScreenState();
}

class PanchangScreenState extends State<PanchangScreen> {
  late DateTime _date;
  late DateTime _month;
  late PanchangCity _city;
  late PanchangDay _day;
  PanchangTerms? _terms;
  PanchangPage _page = PanchangPage.keyDays;
  EkadashiTradition _tradition = EkadashiTradition.smarta;
  final _locationStore = PanchangLocationStore();
  late final PageController _pages;

  /// Each page keeps its own scroll position while it is shown.
  final _scrollControllers = {
    for (final page in PanchangPage.values) page: ScrollController(),
  };
  bool _locationChanged = false;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity ?? PanchangCity.newDelhi;
    final start = widget.initialDate ?? _today();
    _date = DateTime.utc(start.year, start.month, start.day);
    _month = DateTime.utc(_date.year, _date.month);
    if (widget.initialDate != null) _page = PanchangPage.daily;
    _pages = PageController(initialPage: _page.index);
    _recalculate();
    PanchangTerms.load().then((terms) {
      if (mounted) setState(() => _terms = terms);
    });
    PlaceNames.load().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.initialCity == null) _restoreLocation();
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Opens [date] on the Daily page (event reminders, deep links).
  void showDate(DateTime date) {
    setState(() {
      _date = DateTime.utc(date.year, date.month, date.day);
      _month = DateTime.utc(_date.year, _date.month);
      _recalculate();
    });
    _showPage(PanchangPage.daily);
    final daily = _scrollControllers[PanchangPage.daily]!;
    if (daily.hasClients) daily.jumpTo(0);
  }

  /// A chip, a Key day or a deep link chose [page].
  void _showPage(PanchangPage page) {
    setState(() => _page = page);
    showSectionPage(_pages, page.index);
  }

  void _recalculate() => _day = widget.engine.calculate(_date, city: _city);

  DateTime _today() {
    final now = _city.wallClock(DateTime.now());
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Every sub-tab shows the selected date, so Today means today's date.
  bool _isToday(PanchangPage page) => _date == _today();

  /// Selects [date] on every sub-tab; the monthly ones browse its month.
  void _select(DateTime date) {
    _date = DateTime.utc(date.year, date.month, date.day);
    _month = DateTime.utc(_date.year, _date.month);
    _recalculate();
  }

  Future<void> _restoreLocation() async {
    final city = await _locationStore.load();
    if (!mounted || city == null || _locationChanged) return;
    setState(() {
      _city = city;
      if (widget.initialDate == null) {
        _date = _today();
        _month = DateTime.utc(_date.year, _date.month);
      }
      _recalculate();
    });
  }

  /// A new city keeps "today" on the new city's today.
  Future<void> _changeCity(PanchangCity? city) async {
    if (city == null || city == _city) return;
    _locationChanged = true;
    final wasToday = _date == _today();
    setState(() {
      _city = city;
      if (wasToday) {
        _select(_today());
      } else {
        _recalculate();
      }
    });
    if (widget.initialCity != null) return;
    try {
      await _locationStore.save(city);
      // Festival reminders follow the Panchang location.
      EventReminderService.instance.changed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text('panchang_location_not_saved'))),
        );
      }
    }
  }

  Future<void> _editLocation() async {
    final city = await showDialog<PanchangCity>(
      context: context,
      builder: (_) => PanchangLocationDialog(city: _city),
    );
    if (mounted) await _changeCity(city);
  }

  void _goToToday() => setState(() => _select(_today()));

  /// Monthly sub-tabs move a month, keeping the day of the month (the last
  /// day of a shorter month); the others move a day.
  void _step(PanchangPage page, int offset) => setState(() {
    if (page.isMonthly) {
      final lastDay = DateTime.utc(_date.year, _date.month + offset + 1, 0).day;
      _select(
        DateTime.utc(
          _date.year,
          _date.month + offset,
          _date.day > lastDay ? lastDay : _date.day,
        ),
      );
    } else {
      _select(_date.add(Duration(days: offset)));
    }
  });

  Future<void> _pick(PanchangPage page) async {
    final language = _language;
    if (page.isMonthly) {
      final month = await showDialog<DateTime>(
        context: context,
        builder: (_) =>
            PanchangMonthPickerDialog(month: _month, language: language),
      );
      if (month != null && mounted) {
        // Today in the current month, else the month's first day.
        final today = _today();
        setState(
          () => _select(
            month.year == today.year && month.month == today.month
                ? today
                : month,
          ),
        );
      }
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      locale: Locale(language),
    );
    if (date != null && mounted) {
      setState(() => _select(date));
    }
  }

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;

  String _text(String key) => AppStrings.translate(key, _language);

  @override
  Widget build(BuildContext context) {
    final language = context
        .watch<LanguageService>()
        .currentLocale
        .languageCode;
    final premium = context.select<PremiumService?, bool>(
      (service) => service?.isPremium ?? false,
    );
    String t(String key) => AppStrings.translate(key, language);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _sectionBar(t),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: PanchangPage.values.length,
              onPageChanged: (index) =>
                  setState(() => _page = PanchangPage.values[index]),
              itemBuilder: (_, index) {
                final page = PanchangPage.values[index];
                return KeyedSubtree(
                  key: ValueKey(page),
                  child: CustomScrollView(
                    controller: _scrollControllers[page],
                    key: const Key('panchang_scroll_view'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        sliver: SliverList.list(
                          children: [
                            _controls(t, language, page),
                            const SizedBox(height: 16),
                            _content(premium, page),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBar(String Function(String) t) => SectionChipBar(
    key: const Key('panchang_sections_tube'),
    labels: [for (final page in PanchangPage.values) t(page.titleKey)],
    chipKeys: [
      for (final page in PanchangPage.values) Key('panchang_tab_${page.raw}'),
    ],
    selected: _page.index,
    onSelected: (index) => _showPage(PanchangPage.values[index]),
  );

  /// The location and notes, then the month or day being shown and Today.
  Widget _controls(
    String Function(String) t,
    String language,
    PanchangPage page,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(child: _locationMenu(t)),
          if (_city.timeZoneId != 'Asia/Kolkata') ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _city.timeZoneLabel(_language),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            key: const Key('panchang_notes'),
            tooltip: t('panchang_notes_title'),
            icon: const Icon(Icons.info_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => PanchangNotesSheet(language: language),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _stepper(t, language, page)),
          const SizedBox(width: 6),
          TextButton(
            key: const Key('panchang_today'),
            onPressed: _isToday(page) ? null : _goToToday,
            child: Text(t('today')),
          ),
        ],
      ),
    ],
  );

  Widget _locationMenu(String Function(String) t) {
    final cities = {...PanchangCity.supported, _city}.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return PopupMenuButton<Object>(
      key: const Key('panchang_city_selector'),
      tooltip: t('panchang_location_title'),
      onSelected: (value) =>
          value is PanchangCity ? _changeCity(value) : _editLocation(),
      itemBuilder: (_) => [
        for (final city in cities)
          PopupMenuItem(
            value: city,
            child: Row(
              children: [
                Expanded(child: Text(PlaceNames.label(city.label, _language))),
                if (city == _city)
                  const Icon(
                    Icons.check,
                    size: 18,
                    color: GlassTubeColors.teal,
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          key: const Key('panchang_edit_location'),
          value: 'search',
          child: Row(
            children: [
              const Icon(Icons.search, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(t('panchang_search_location'))),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: GlassTubeColors.foreground(context).withValues(alpha: .08),
          border: Border.all(
            color: GlassTubeColors.foreground(context).withValues(alpha: .14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.place_outlined,
              size: 18,
              color: GlassTubeColors.teal,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                PlaceNames.label(_city.label, _language),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _stepper(
    String Function(String) t,
    String language,
    PanchangPage page,
  ) {
    final monthly = page.isMonthly;
    // Every sub-tab shows the weekday, date, month and year.
    final title = PanchangFormat.date(_date, language);
    return GlassTube(
      key: const Key('panchang_stepper'),
      optionCount: 3,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      radius: 16,
      child: Row(
        children: [
          IconButton(
            key: Key(
              monthly ? 'panchang_previous_month' : 'panchang_previous_day',
            ),
            tooltip: t('panchang_previous'),
            icon: const Icon(Icons.chevron_left, color: GlassTubeColors.teal),
            onPressed: () => _step(page, -1),
          ),
          Expanded(
            child: TextButton(
              key: Key(
                monthly ? 'panchang_selected_month' : 'panchang_selected_date',
              ),
              onPressed: () => _pick(page),
              style: TextButton.styleFrom(
                foregroundColor: GlassTubeColors.foreground(context),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: Key(monthly ? 'panchang_next_month' : 'panchang_next_day'),
            tooltip: t('panchang_next'),
            icon: const Icon(Icons.chevron_right, color: GlassTubeColors.teal),
            onPressed: () => _step(page, 1),
          ),
        ],
      ),
    );
  }

  Widget _content(bool premium, PanchangPage page) {
    final terms = _terms;
    if (terms == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(color: GlassTubeColors.teal),
        ),
      );
    }
    switch (page) {
      case PanchangPage.keyDays:
        return PanchangKeyDaysView(
          month: _month,
          city: _city,
          ekadashiList: widget.ekadashiList,
          onOpen: showDate,
        );
      case PanchangPage.daily:
        return PanchangDailyView(day: _day, terms: terms);
      case PanchangPage.muhurta:
        return premium
            ? PanchangMuhurtaView(day: _day, terms: terms)
            : const PanchangUpgradeCard();
      case PanchangPage.ekadashi:
        return PanchangEkadashiView(
          month: _month,
          city: _city,
          tradition: _tradition,
          terms: terms,
          onTraditionChanged: (value) => setState(() => _tradition = value),
        );
      case PanchangPage.rashi:
        return premium
            ? PanchangRashiView(day: _day, terms: terms)
            : const PanchangUpgradeCard();
    }
  }
}

/// A year and its twelve months (the iOS month and year wheels).
class PanchangMonthPickerDialog extends StatefulWidget {
  const PanchangMonthPickerDialog({
    super.key,
    required this.month,
    required this.language,
    this.years,
  });
  final DateTime month;
  final String language;

  /// The years offered as chips (the Calendar's data years); any year with
  /// arrows when null.
  final List<int>? years;

  @override
  State<PanchangMonthPickerDialog> createState() =>
      _PanchangMonthPickerDialogState();
}

class _PanchangMonthPickerDialogState extends State<PanchangMonthPickerDialog> {
  late int _year = widget.month.year;

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final years = widget.years;
    return AlertDialog(
      key: const Key('panchang_month_picker'),
      title: years != null
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final year in years)
                  ChoiceChip(
                    key: Key('month_picker_year_$year'),
                    label: Text('$year'),
                    selected: _year == year,
                    showCheckmark: false,
                    selectedColor: GlassTubeColors.teal.withValues(alpha: .2),
                    onSelected: (_) => setState(() => _year = year),
                  ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  onPressed: _year > 1900
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: Text('$_year', textAlign: TextAlign.center)),
                IconButton(
                  onPressed: _year < 2100
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 1.8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var m = 1; m <= 12; m++)
              () {
                final selected =
                    _year == widget.month.year && m == widget.month.month;
                return Material(
                  color: selected
                      ? GlassTubeColors.teal
                      : GlassTubeColors.foreground(
                          context,
                        ).withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: Key('panchang_month_$m'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        Navigator.of(context).pop(DateTime.utc(_year, m)),
                    child: Center(
                      child: Text(
                        PanchangFormat.format(
                          DateTime.utc(2026, m),
                          'LLL',
                          language,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.translate('cancel', language)),
        ),
      ],
    );
  }
}

/// How the Panchang is calculated, in a few lines (replaces the Guide tab).
class PanchangNotesSheet extends StatelessWidget {
  const PanchangNotesSheet({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppStrings.translate(key, language);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('panchang_notes_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('panchang_notes_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(t('panchang_notes_body')),
            const SizedBox(height: 12),
            Text(t('panchang_notes_traditions')),
            const SizedBox(height: 12),
            Text(
              t('panchang_notes_sources'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
