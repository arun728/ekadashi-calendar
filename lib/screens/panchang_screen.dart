import 'package:flutter/material.dart';
import '../widgets/tab_shell.dart';
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
import '../widgets/app_background.dart';
import '../widgets/glass_tube.dart';
import '../widgets/ios_style.dart';
import '../widgets/section_pager.dart';
import 'panchang_location_dialog.dart';
import 'panchang_pages.dart';
import 'widgets/month_year_picker.dart';

export 'widgets/month_year_picker.dart' show PanchangMonthPickerDialog;

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
    this.locationStore,
    this.barSlots,
  });

  /// Today and the calculation notes go in the shared top bar (iOS toolbar).
  final TabBarSlots? barSlots;

  final DateTime? initialDate;
  final PanchangCity? initialCity;

  /// The published schedule in the app language (Key days lists it).
  final List<EkadashiDate> ekadashiList;
  final PanchangEngine engine;

  /// Where the chosen city is kept (tests pass a slow one).
  final PanchangLocationStore? locationStore;

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
  late final _locationStore = widget.locationStore ?? PanchangLocationStore();
  late final PageController _pages;

  /// Each page keeps its own scroll position while it is shown.
  final _scrollControllers = {
    for (final page in PanchangPage.values) page: ScrollController(),
  };
  bool _locationChanged = false;

  /// A day was opened or picked, so restoring the city keeps it.
  bool _dateChosen = false;

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
    widget.barSlots?.attach(leading: _barLeading, actions: _barActions);
  }

  @override
  void dispose() {
    widget.barSlots?.detach();
    _pages.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Opens [date] on the Daily page (event reminders, deep links).
  void showDate(DateTime date) {
    setState(() => _select(date));
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

  /// Selects [date] on every sub-tab; the monthly ones browse its month.
  void _select(DateTime date) {
    _dateChosen = true;
    _date = DateTime.utc(date.year, date.month, date.day);
    _month = DateTime.utc(_date.year, _date.month);
    _recalculate();
  }

  Future<void> _restoreLocation() async {
    final city = await _locationStore.load();
    if (!mounted || city == null || _locationChanged) return;
    setState(() {
      _city = city;
      // Only move a date nobody chose: a tapped reminder (showDate) or the
      // user may have picked one before the saved city arrived.
      if (widget.initialDate == null && !_dateChosen) {
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
      if (mounted) showToast(context, _text('panchang_location_not_saved'));
    }
  }

  Future<void> _editLocation() async {
    final city = await showAppSheet<PanchangCity>(
      context,
      builder: (_) => PanchangLocationSheet(city: _city),
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
      final month = await showMonthYearPicker(
        context,
        month: _month,
        language: language,
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
    // iOS: a sheet with the graphical calendar; a picked day shows at
    // once, Today jumps to today and Done closes.
    await showAppSheet<void>(
      context,
      large: false,
      builder: (sheetContext) => PanchangDayPickerSheet(
        date: _date,
        language: language,
        onPicked: (date) {
          if (mounted) setState(() => _select(date));
        },
        onToday: () {
          if (mounted) _goToToday();
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  /// The iOS toolbar: Today (leading) and the calculation notes (trailing).
  Widget _barLeading(BuildContext context) => BarTextButton(
    key: const Key('panchang_today'),
    label: _text('today'),
    onPressed: _date == _today() ? null : _goToToday,
  );

  List<Widget> _barActions(BuildContext context) => [
    IconButton(
      key: const Key('panchang_notes'),
      tooltip: _text('panchang_notes_title'),
      color: IosColors.teal,
      icon: const Icon(Icons.info_outline),
      onPressed: _showNotes,
    ),
  ];

  void _showNotes() => showAppSheet<void>(
    context,
    large: false,
    builder: (_) => PanchangNotesSheet(language: _language),
  );

  /// What the top bar shows; it is rebuilt when this changes.
  String? _barState;

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
    final barState = '$language|${_date == _today()}';
    if (barState != _barState) {
      _barState = barState;
      widget.barSlots?.refresh();
    }
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

  /// The location (time zone at the far right), then the month or day
  /// being shown (iOS PanchangView.controls).
  Widget _controls(
    String Function(String) t,
    String language,
    PanchangPage page,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(flex: 3, child: _locationMenu(t)),
          if (_city.timeZoneId != 'Asia/Kolkata') ...[
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Text(
                _city.timeZoneLabel(_language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: IosText.caption,
                  color: IosColors.secondary(context),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),
      _stepper(t, language, page),
    ],
  );

  Widget _locationMenu(String Function(String) t) {
    final cities = {...PanchangCity.supported, _city}.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return PopupMenuButton<Object>(
      key: const Key('panchang_city_selector'),
      tooltip: t('panchang_location_title'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) =>
          value is PanchangCity ? _changeCity(value) : _editLocation(),
      itemBuilder: (_) => [
        for (final city in cities)
          PopupMenuItem(
            value: city,
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: city == _city
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: IosColors.primary(context),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    PlaceNames.label(city.label, _language),
                    style: const TextStyle(fontSize: IosText.body),
                  ),
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
              Expanded(
                child: Text(
                  t('panchang_search_location'),
                  style: const TextStyle(fontSize: IosText.body),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.search, size: 18, color: IosColors.primary(context)),
            ],
          ),
        ),
      ],
      // iOS: a glass capsule with mappin.and.ellipse, the city (subheadline
      // semibold) and a small chevron.
      child: GlassPanel(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pin_drop, size: 17, color: IosColors.teal),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                PlaceNames.label(_city.label, _language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: IosText.subheadline,
                  fontWeight: FontWeight.w600,
                  color: IosColors.teal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: IosColors.teal,
            ),
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
    // The stepper's buttons are all teal (iOS foregroundStyle(Theme.teal)).
    const primary = IosColors.teal;
    return GlassPanel(
      key: const Key('panchang_stepper'),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            key: Key(
              monthly ? 'panchang_previous_month' : 'panchang_previous_day',
            ),
            tooltip: t('panchang_previous'),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, color: IosColors.teal),
            onPressed: () => _step(page, -1),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextButton(
              key: Key(
                monthly ? 'panchang_selected_month' : 'panchang_selected_date',
              ),
              onPressed: () => _pick(page),
              style: TextButton.styleFrom(
                foregroundColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: IosText.headline,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: Key(monthly ? 'panchang_next_month' : 'panchang_next_day'),
            tooltip: t('panchang_next'),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_right, color: IosColors.teal),
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

/// How the Panchang is calculated, in a few lines (replaces the Guide tab):
/// an iOS sheet with an inline title and Done.
class PanchangNotesSheet extends StatelessWidget {
  const PanchangNotesSheet({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppStrings.translate(key, language);
    final body = TextStyle(
      fontSize: IosText.body,
      color: IosColors.primary(context),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetBar(
          title: t('panchang_notes_title'),
          trailing: BarTextButton(
            key: const Key('panchang_notes_done'),
            label: t('panchang_done'),
            bold: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            key: const Key('panchang_notes_sheet'),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('panchang_notes_body'), style: body),
                  const SizedBox(height: 14),
                  Text(t('panchang_notes_traditions'), style: body),
                  const SizedBox(height: 14),
                  Text(
                    t('panchang_notes_sources'),
                    style: TextStyle(
                      fontSize: IosText.footnote,
                      color: IosColors.secondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The day picker (iOS: a sheet with the graphical DatePicker, Today and
/// Done). A tapped day applies at once, as the iOS binding does.
class PanchangDayPickerSheet extends StatefulWidget {
  const PanchangDayPickerSheet({
    super.key,
    required this.date,
    required this.language,
    required this.onPicked,
    required this.onToday,
  });

  final DateTime date;
  final String language;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onToday;

  @override
  State<PanchangDayPickerSheet> createState() => _PanchangDayPickerSheetState();
}

class _PanchangDayPickerSheetState extends State<PanchangDayPickerSheet> {
  late final DateTime _initial = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppStrings.translate(key, widget.language);
    return Column(
      key: const Key('panchang_day_picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetBar(
          title: '',
          leading: BarTextButton(
            key: const Key('panchang_day_picker_today'),
            label: t('today'),
            onPressed: widget.onToday,
          ),
          trailing: BarTextButton(
            key: const Key('panchang_day_picker_done'),
            label: t('panchang_done'),
            bold: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SafeArea(
              top: false,
              child: Localizations.override(
                context: context,
                locale: Locale(widget.language),
                child: CalendarDatePicker(
                  initialDate: _initial,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100, 12, 31),
                  onDateChanged: widget.onPicked,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panchang opened from a search result. iOS pushes PanchangView in the
/// search's navigation stack: the teal background, an inline title with
/// the back button and Today, and the calculation notes on the right.
class PanchangPushedPage extends StatefulWidget {
  const PanchangPushedPage({
    super.key,
    required this.title,
    this.initialDate,
    this.initialCity,
  });

  final String title;
  final DateTime? initialDate;
  final PanchangCity? initialCity;

  @override
  State<PanchangPushedPage> createState() => _PanchangPushedPageState();
}

class _PanchangPushedPageState extends State<PanchangPushedPage> {
  final _slots = TabBarSlots();

  @override
  void dispose() {
    _slots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ListenableBuilder(
          listenable: _slots,
          builder: (context, _) {
            final today = _slots.leading(context);
            return AppBar(
              automaticallyImplyLeading: false,
              leadingWidth: 150,
              leading: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const BackButton(), ?today],
                ),
              ),
              title: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [..._slots.actions(context), const SizedBox(width: 4)],
            );
          },
        ),
      ),
      body: PanchangScreen(
        barSlots: _slots,
        initialDate: widget.initialDate,
        initialCity: widget.initialCity,
      ),
    ),
  );
}
