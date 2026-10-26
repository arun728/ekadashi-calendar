import '../l10n/app_language.dart';
import 'premium_screen.dart';
import '../services/premium_service.dart';
import '../widgets/ios_style.dart';
import 'dart:async';
import '../services/display_clock.dart';
import '../services/ekadashi_lifecycle.dart';
import '../widgets/ekadashi_lifecycle_status.dart';
import '../models/calendar_entry.dart';
import '../models/calendar_day_merge.dart';
import '../data/calendar_entry_repository.dart';
import '../data/sqflite_calendar_entry_repository.dart';
import '../services/google_calendar_service.dart';
import '../services/google_auth_gateway_android.dart';
import '../services/google_calendar_prefs.dart';
import '../services/free_sync_registry.dart';
import 'dart:convert';
import 'widgets/calendar_filter_bar.dart';
import 'widgets/day_entries_list.dart';
import 'widgets/add_edit_entry_sheet.dart';
import 'widgets/google_calendar_picker_sheet.dart';
import 'package:flutter/material.dart';
import '../widgets/tab_shell.dart';
import '../services/notifications/event_reminder_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ekadashi_service.dart';
import '../services/ekadashi_settings.dart';
import '../services/place_name_resolver.dart';
import '../services/language_service.dart';
import 'package:intl/intl.dart';
import 'details_screen.dart';
import 'widgets/month_year_picker.dart';
import '../services/vrat_tracker_service.dart';
import '../models/vrat_tracker_models.dart';
import '../widgets/app_icons.dart';

class CalendarScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;

  /// Today, Add and Google go in the shared top bar (iOS toolbar).
  final TabBarSlots? barSlots;
  final String? currentTimezone;
  final CalendarEntryRepository? repository;
  final GoogleCalendarService? googleService;

  /// Overrides "now" in tests.
  final DateTime Function()? clock;

  /// Per-Google-account record of the free sync; defaults to the free
  /// Firestore registry when it is configured at build time.
  final FreeSyncRegistry? freeSyncRegistry;

  /// Set after a free user's one free Google Calendar sync (Android Auto
  /// Backup restores it after a reinstall).
  static const freeSyncUsedKey = 'google_free_sync_used';

  /// The month ("yyyy-MM") of the free sync; its events stay after a lapse.
  static const freeSyncMonthKey = 'google_free_sync_month';

  /// What Premium synced (account, calendars and range), so it can be removed
  /// when Google Play confirms the subscription has ended.
  static const premiumSyncKey = 'google_premium_sync_v1';

  const CalendarScreen({
    super.key,
    required this.ekadashiList,
    this.barSlots,
    this.currentTimezone,
    this.repository,
    this.googleService,
    this.clock,
    this.freeSyncRegistry,
  });

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  /// Month changes slide visibly, the same for arrows, swipes and the
  /// grid's own paging (CalendarView.monthSlide on iOS).
  static const monthSlide = Duration(milliseconds: 250);

  /// Home's city, tradition and year; the Calendar stays on Home's year.
  EkadashiSettings? _settings;

  /// The enabled Ekadashi years (assets/calendar/ekadashi_years.json).
  List<int> get _years {
    final enabled = _settings?.years;
    if (enabled != null && enabled.isNotEmpty) return enabled;
    return widget.ekadashiList.map((e) => e.date.year).toSet().toList()..sort();
  }

  /// The year shown in the selector; it follows the month on screen.
  late int _selectedYear;

  /// The calendar spans every bundled year pack (assets/calendar/<year>.json
  /// listed in manifest.json), so adding a 2028 pack extends it with no code
  /// change, and past years stay browsable after the new year starts.
  DateTime get _firstDay =>
      DateTime(_years.isEmpty ? _selectedYear : _years.first, 1, 1);
  DateTime get _lastDay =>
      DateTime(_years.isEmpty ? _selectedYear : _years.last, 12, 31);

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  EkadashiDate? _selectedEkadashi;
  late final CalendarEntryRepository _repo;
  late final GoogleCalendarService _google;
  List<CalendarEntry> _entries = [];
  CalendarFilter _filter = CalendarDayMerge.defaultFilter;
  bool _repoReady = false;
  bool _repoError = false;
  bool _syncing = false;
  PageController? _monthPager;
  late final FreeSyncRegistry? _registry =
      widget.freeSyncRegistry ?? FirestoreFreeSyncRegistry.fromEnvironment();
  PremiumService? _premium;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _premium ??= context.read<PremiumService?>()
      ?..addListener(_onPremiumChanged);
  }

  /// Every change also refreshes the top bar items (Today, Add, Google).
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.barSlots?.refresh();
  }

  void _onPremiumChanged() {
    if (_repoReady) _removeLapsedPremiumSync();
  }

  void selectDate(DateTime date) {
    if (!_years.contains(date.year)) return;
    setState(() {
      _selectedYear = date.year;
      _focusedDay = date;
      _selectedDay = date;
      _checkSelectedDayEkadashi();
    });
    _showsYear(date.year);
    if (_repoReady) _reloadEntries();
  }

  /// The Calendar moved into another year: Home follows.
  void _showsYear(int year) => _settings?.setYear(year);

  /// Home's year menu chose another year: today in it, else its January.
  void _homeYearChanged() {
    final year = _settings?.year;
    if (!mounted || year == null || year == _focusedDay.year) return;
    final now = _now();
    final target = now.year == year
        ? DateTime(now.year, now.month, now.day)
        : DateTime(year, 1, 1);
    setState(() {
      _selectedYear = year;
      _focusedDay = target;
      _selectedDay = target;
    });
    _checkSelectedDayEkadashi();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SqfliteCalendarEntryRepository();
    _google =
        widget.googleService ??
        GoogleCalendarService(
          auth: GoogleAuthGatewayAndroid(),
          repository: _repo,
        );
    _initRepo();
    widget.barSlots?.attach(leading: _todayButton, actions: _barActions);
    _settings = context.read<EkadashiSettings?>()
      ?..addListener(_homeYearChanged);
    // Opens on Home's year: today in it, else its January.
    var now = _now();
    final homeYear = _settings?.year;
    if (homeYear != null && homeYear != now.year) now = DateTime(homeYear);
    _selectedYear = _years.contains(now.year)
        ? now.year
        : (_years.isEmpty ? now.year : _years.last);
    if (now.isBefore(_firstDay)) {
      _focusedDay = _firstDay;
      _selectedDay = _firstDay;
    } else if (now.isAfter(_lastDay)) {
      _focusedDay = _lastDay;
      _selectedDay = _lastDay;
    } else {
      _focusedDay = now;
      _selectedDay = now;
    }
    _checkSelectedDayEkadashi();
  }

  @override
  void dispose() {
    widget.barSlots?.detach();
    _premium?.removeListener(_onPremiumChanged);
    _settings?.removeListener(_homeYearChanged);
    if (widget.repository == null) {
      unawaited(_repo.close().catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _initRepo() async {
    try {
      await _repo.init();
      await _removeLapsedPremiumSync(notify: false);
      await _reloadEntries();
      if (mounted) {
        setState(() {
          _repoReady = true;
          _repoError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _repoReady = false;
          _repoError = true;
        });
      }
    }
  }

  /// Once Google Play confirms premium has ended, removes the Google events
  /// that Premium synced. Events of the one free month stay.
  Future<void> _removeLapsedPremiumSync({bool notify = true}) async {
    if (_premium?.lapsed != true) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CalendarScreen.premiumSyncKey);
    if (raw == null) return;
    final record = jsonDecode(raw) as Map<String, dynamic>;
    final account = record['account'] as String;
    final calendars = (record['calendars'] as List).cast<String>();
    final start = DateTime.parse(record['start'] as String);
    final end = DateTime.parse(record['end'] as String);
    var ranges = [(start, end)];
    final freeMonth = prefs.getString(CalendarScreen.freeSyncMonthKey);
    if (freeMonth != null) {
      final keepStart = DateTime.parse('$freeMonth-01');
      final keepEnd = DateTime(keepStart.year, keepStart.month + 1);
      if (start.isBefore(keepEnd) && end.isAfter(keepStart)) {
        ranges = [
          if (start.isBefore(keepStart)) (start, keepStart),
          if (end.isAfter(keepEnd)) (keepEnd, end),
        ];
      }
    }
    for (final (from, to) in ranges) {
      await _repo.replaceGoogleWindow(
        accountId: account,
        calendarIds: calendars,
        timeMin: from,
        timeMax: to,
        entries: const [],
      );
    }
    await prefs.remove(CalendarScreen.premiumSyncKey);
    EventReminderService.instance.changed();
    if (notify) {
      await _reloadEntries();
      _showMessage('google_premium_events_removed');
    }
  }

  /// Merges a premium sync into the record used for removal after a lapse.
  Future<void> _rememberPremiumSync(
    SharedPreferences prefs,
    String account,
    List<String> calendars,
    DateTime start,
    DateTime end,
  ) async {
    final raw = prefs.getString(CalendarScreen.premiumSyncKey);
    final old = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    if (old != null && old['account'] == account) {
      final oldStart = DateTime.parse(old['start'] as String);
      final oldEnd = DateTime.parse(old['end'] as String);
      if (oldStart.isBefore(start)) start = oldStart;
      if (oldEnd.isAfter(end)) end = oldEnd;
      calendars = {
        ...(old['calendars'] as List).cast<String>(),
        ...calendars,
      }.toList();
    }
    await prefs.setString(
      CalendarScreen.premiumSyncKey,
      jsonEncode({
        'account': account,
        'calendars': calendars,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      }),
    );
  }

  Future<void> _reloadEntries() async {
    final entries = await _repo.getAll();
    if (mounted) setState(() => _entries = entries);
  }

  /// The entry editor saves from its sheet; a storage error keeps it open.
  /// The filter stays as it is, as on iOS.
  Future<void> _editEntry({CalendarEntry? existing}) async {
    await AddEditEntrySheet.show(
      context,
      initialDay: _selectedDay,
      existing: existing,
      onSave: (entry) async {
        try {
          await _repo.upsert(entry);
          await _reloadEntries();
          EventReminderService.instance.changed();
          return true;
        } catch (_) {
          _showMessage('storage_failed');
          return false;
        }
      },
    );
  }

  /// The iOS toast; [upsell] adds an Upgrade action to the paywall.
  void _showMessage(String key, {List<String>? args, bool upsell = false}) {
    if (!mounted) return;
    final lang = context.read<LanguageService>();
    showToast(
      context,
      args == null ? lang.translate(key) : lang.translateWithArgs(key, args),
      actionLabel: upsell ? lang.translate('premium_upgrade') : null,
      onAction: upsell
          ? () => openPremium(
              context,
              currentTimezone: widget.currentTimezone ?? 'IST',
            )
          : null,
    );
  }

  DateTime _now() => EkadashiLifecycle.localDay(
    (widget.clock ?? DisplayClock.now)(),
    _settings?.city.timeZoneId ?? widget.currentTimezone ?? 'IST',
  );

  bool _isPremium() => context.read<PremiumService?>()?.isPremium == true;

  /// Opens the paywall; true when the user now has premium.
  Future<bool> _unlockPremium({String? reasonKey}) async {
    await openPremium(
      context,
      currentTimezone: widget.currentTimezone ?? 'IST',
      reasonKey: reasonKey,
    );
    return mounted && _isPremium();
  }

  /// Premium (an active Play subscription or lifetime purchase, re-checked
  /// with Google Play at every sync) imports the whole subscription year.
  /// Free users get one sync ever, of the month being viewed; it is recorded
  /// on the phone and in the Google account, and is only used up by a
  /// successful import.
  Future<void> _syncYear() async {
    if (_syncing || !_repoReady) return;
    final month = DateTime(_focusedDay.year, _focusedDay.month);
    final premiumService = context.read<PremiumService?>();
    final languageCode = context
        .read<LanguageService>()
        .currentLocale
        .languageCode;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    var premium = _isPremium();
    if (!premium && prefs.getBool(CalendarScreen.freeSyncUsedKey) == true) {
      // Continue straight into the import after a successful purchase.
      if (!await _unlockPremium(reasonKey: 'google_free_sync_used')) return;
      premium = true;
    }
    setState(() => _syncing = true);
    // Names the step a failed sync stopped at in the device log.
    var stage = 'sign_in';
    try {
      final bool signedIn;
      try {
        signedIn = await _google.isSignedIn() || await _google.signIn();
      } catch (_) {
        _showMessage('google_sign_in_failed');
        return;
      }
      if (!signedIn) {
        _showMessage('sign_in_cancelled');
        return;
      }
      String? googleIdToken;
      stage = 'free_sync_registry';
      if (!premium && _registry != null) {
        googleIdToken = await _google.auth.idToken();
        if (googleIdToken == null) throw StateError('No Google ID token');
      }
      var freeSyncAvailable = true;
      var paywallReason = 'google_free_sync_used';
      if (!premium && googleIdToken != null) {
        try {
          if (await _registry!.isUsed(googleIdToken)) {
            // This Google account used its free sync before (e.g. before a
            // reinstall or on another phone).
            freeSyncAvailable = false;
            await prefs.setBool(CalendarScreen.freeSyncUsedKey, true);
          }
        } catch (error) {
          // The free sync cannot be confirmed, so none is handed out; offer
          // Premium instead of an error. The free sync stays available.
          debugPrint('Free sync check failed: $error');
          freeSyncAvailable = false;
          paywallReason = 'free_sync_unverified';
        }
      }
      if (!premium && !freeSyncAvailable) {
        if (!mounted) return;
        setState(() => _syncing = false);
        if (!await _unlockPremium(reasonKey: paywallReason)) return;
        premium = true;
        setState(() => _syncing = true);
      }
      final window = premium
          ? premiumService!.syncWindow(
              _now(),
              calendarYears: _years.isEmpty
                  ? null
                  : (first: _years.first, last: _years.last),
            )!
          : (start: month, end: DateTime(month.year, month.month + 1));
      stage = 'list_calendars';
      final account = await _google.auth.accountId();
      if (account == null) throw StateError('No Google account');
      final calendars = await _google.listCalendars();
      if (calendars.isEmpty) {
        _showMessage('no_google_calendars');
        return;
      }
      final saved = await GoogleCalendarPrefs.loadSelectedIds(account);
      final email = await _google.auth.accountEmail();
      if (!mounted) return;
      final chosen = await showGoogleCalendarPickerSheet(
        context: context,
        calendars: calendars,
        initiallySelected: saved,
        accountEmail: email,
      );
      if (identical(chosen, switchGoogleAccountResult)) {
        // Forget the remembered account so the next sign-in shows Google's
        // account chooser. Imported events of the old account are kept.
        await _google.auth.signOut();
        if (mounted) setState(() => _syncing = false);
        await _syncYear();
        return;
      }
      if (chosen == null || chosen.isEmpty) return;
      // The window was fixed before the picker: changing the month or year
      // while a request runs cannot silently change the import range.
      stage = 'import';
      final count = await _google.syncImport(
        timeMin: window.start,
        timeMax: window.end,
        calendarIds: chosen,
      );
      await GoogleCalendarPrefs.saveSelectedIds(account, chosen);
      await _reloadEntries();
      if (!premium) {
        await prefs.setBool(CalendarScreen.freeSyncUsedKey, true);
        await prefs.setString(
          CalendarScreen.freeSyncMonthKey,
          month.toIso8601String().substring(0, 7),
        );
        if (googleIdToken != null) {
          try {
            await _registry!.record(googleIdToken, month);
          } catch (_) {
            // Best effort: this phone already remembers the free sync.
          }
        }
        _showMessage('google_free_sync_used', upsell: true);
      } else {
        await _rememberPremiumSync(
          prefs,
          account,
          chosen,
          window.start,
          window.end,
        );
        final format = DateFormat.yMMM(languageCode);
        _showMessage(
          'imported_google_range',
          args: [
            '$count',
            format.format(window.start),
            format.format(DateTime(window.end.year, window.end.month - 1)),
          ],
        );
      }
    } catch (error) {
      debugPrint('Google Calendar sync failed at $stage: $error');
      _showMessage('google_sync_failed');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnectGoogle() async {
    if (_syncing || !_repoReady) return;
    setState(() => _syncing = true);
    try {
      // Premium belongs to the Google Play purchase, not this Google sign-in.
      await _google.signOut();
      await _reloadEntries();
    } catch (_) {
      _showMessage('google_sync_failed');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When ekadashiList changes (e.g., language or timezone change), refresh the selected ekadashi
    if (widget.ekadashiList != oldWidget.ekadashiList ||
        widget.currentTimezone != oldWidget.currentTimezone) {
      _checkSelectedDayEkadashi();
    }
  }

  void _checkSelectedDayEkadashi() {
    final selected = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    for (var ekadashi in widget.ekadashiList) {
      final ekadashiDate = DateTime(
        ekadashi.date.year,
        ekadashi.date.month,
        ekadashi.date.day,
      );
      if (ekadashiDate == selected) {
        setState(() => _selectedEkadashi = ekadashi);
        return;
      }
    }
    setState(() => _selectedEkadashi = null);
  }

  /// The selected year, for tests and deep links.
  int get selectedYear => _selectedYear;

  bool get _showsToday {
    final now = _now();
    return isSameDay(_selectedDay, now) &&
        _focusedDay.year == now.year &&
        _focusedDay.month == now.month;
  }

  Future<void> _pickMonth() async {
    final lang = context.read<LanguageService>();
    final month = await showMonthYearPicker(
      context,
      month: DateTime.utc(_focusedDay.year, _focusedDay.month),
      language: lang.currentLocale.languageCode,
      years: _years.isEmpty ? [_selectedYear] : _years,
    );
    if (month == null || !mounted) return;
    // The current month opens on today; any other on its first day.
    final now = _now();
    final target = month.year == now.year && month.month == now.month
        ? DateTime(now.year, now.month, now.day)
        : DateTime(month.year, month.month, 1);
    setState(() {
      _selectedYear = target.year;
      _focusedDay = target;
      _selectedDay = target;
    });
    _checkSelectedDayEkadashi();
    _showsYear(target.year);
  }

  void resetToToday() {
    final now = _now();
    _selectedYear = _years.contains(now.year)
        ? now.year
        : (_years.isEmpty ? now.year : _years.last);
    DateTime targetDay;

    // Clamp to valid range
    if (now.isBefore(_firstDay)) {
      targetDay = _firstDay;
    } else if (now.isAfter(_lastDay)) {
      targetDay = _lastDay;
    } else {
      targetDay = now;
    }

    setState(() {
      _focusedDay = targetDay;
      _selectedDay = targetDay;
    });
    _checkSelectedDayEkadashi();
    _showsYear(targetDay.year);
  }

  bool _isEkadashiDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (var ekadashi in widget.ekadashiList) {
      final ed = DateTime(
        ekadashi.date.year,
        ekadashi.date.month,
        ekadashi.date.day,
      );
      if (ed == d) return true;
    }
    return false;
  }

  // Check if we're at the first month
  bool get _isFirstMonth {
    return _focusedDay.year == _firstDay.year &&
        _focusedDay.month == _firstDay.month;
  }

  // Check if we're at the last month
  bool get _isLastMonth {
    return _focusedDay.year == _lastDay.year &&
        _focusedDay.month == _lastDay.month;
  }

  /// Today at the top left of the bar (iOS toolbar).
  Widget _todayButton(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    return BarTextButton(
      key: const Key('calendar_today'),
      label: lang.translate('today'),
      onPressed: _showsToday ? null : resetToToday,
    );
  }

  /// Add and the Google menu (Import, a red Disconnect) at the top right.
  List<Widget> _barActions(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final red = IosColors.red(context);
    Widget menuRow(String key, IconData icon, Color color) => Row(
      children: [
        Expanded(
          child: Text(
            lang.translate(key),
            style: TextStyle(fontSize: IosText.body, color: color),
          ),
        ),
        const SizedBox(width: 16),
        Icon(icon, size: 20, color: color),
      ],
    );
    return [
      IconButton(
        key: const Key('add_calendar_entry'),
        tooltip: lang.translate('add_entry'),
        color: IosColors.teal,
        onPressed: _repoReady ? () => _editEntry() : null,
        icon: const Icon(AppIcons.add),
      ),
      if (_syncing)
        const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: IosColors.teal,
            ),
          ),
        )
      else
        PopupMenuButton<String>(
          key: const Key('calendar_google_menu'),
          tooltip: lang.translate('google_calendar'),
          enabled: _repoReady,
          icon: const Icon(
            AppIcons.googleMenu,
            size: 28,
            color: IosColors.teal,
          ),
          color: IosColors.groupedCard(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) =>
              value == 'import' ? _syncYear() : _disconnectGoogle(),
          itemBuilder: (context) => [
            PopupMenuItem(
              key: const Key('import_google_year'),
              value: 'import',
              child: menuRow(
                'sync_google',
                AppIcons.googleSync,
                IosColors.primary(context),
              ),
            ),
            PopupMenuItem(
              key: const Key('disconnect_google'),
              value: 'disconnect',
              child: menuRow(
                'disconnect_google',
                AppIcons.googleDisconnect,
                red,
              ),
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final language = lang.currentLocale.languageCode;
    final standalone = widget.barSlots == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Inside the app the shell's top bar shows Today, Add and Google.
      appBar: standalone
          ? AppBar(
              automaticallyImplyLeading: false,
              leadingWidth: 128,
              leading: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: _todayButton(context),
              ),
              actions: [..._barActions(context), const SizedBox(width: 4)],
            )
          : null,
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 100 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (_repoError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.translate('storage_failed'),
                      style: TextStyle(
                        fontSize: IosText.body,
                        color: IosColors.primary(context),
                      ),
                    ),
                  ),
                  BarTextButton(
                    label: lang.translate('retry'),
                    onPressed: _initRepo,
                  ),
                ],
              ),
            ),
          CalendarFilterBar(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 12),
          // A horizontal swipe on the month title, the grid or the selected
          // day changes the month when the finger lifts, as on iOS.
          _MonthSwipe(
            onSwipe: _swipeMonth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _monthHeader(language),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _grid(language),
                ),
                const SizedBox(height: 12),
                Padding(
                  key: const Key('calendar_day_details'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _selectedDaySection(lang),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The selected date (tap for the month and year picker) with a chevron,
  /// and both month arrows together at the right.
  Widget _monthHeader(String language) => Padding(
    key: const Key('calendar_month_tube'),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  key: const Key('calendar_year_selector'),
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            AppStrings.fullDate(_selectedDay, language),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: IosText.title3,
                              fontWeight: FontWeight.w700,
                              // Teal like the iPhone's tinted toolbar title.
                              color: IosColors.teal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        AppIcons.menuDisclosure,
                        size: 18,
                        color: IosColors.teal,
                      ),
                    ],
                  ),
                ),
                // Where and how the Ekadashis are calculated (Home's menus),
                // under the date so short screens keep the day in view.
                if (_settings != null)
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _settings!,
                      PlaceNameResolver.instance,
                    ]),
                    builder: (context, _) => Text(
                      '${AppStrings.translate(_settings!.traditionNameKey, language)} • '
                      '${PlaceNameResolver.instance.city(_settings!.city, language)}',
                      key: const Key('calendar_ekadashi_source'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: IosText.caption,
                        color: IosColors.secondary(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('calendar_previous_month'),
          tooltip: AppStrings.fullDate(_stepped(-1), language),
          color: IosColors.teal,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: _isFirstMonth ? null : () => _swipeMonth(-1),
          icon: const Icon(AppIcons.previous),
        ),
        IconButton(
          key: const Key('calendar_next_month'),
          tooltip: AppStrings.fullDate(_stepped(1), language),
          color: IosColors.teal,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: _isLastMonth ? null : () => _swipeMonth(1),
          icon: const Icon(AppIcons.next),
        ),
      ],
    ),
  );

  /// The selected day a month away, on the same day of the month (its last
  /// day when shorter).
  DateTime _stepped(int months) {
    final last = DateTime(
      _selectedDay.year,
      _selectedDay.month + months + 1,
      0,
    ).day;
    return DateTime(
      _selectedDay.year,
      _selectedDay.month + months,
      _selectedDay.day > last ? last : _selectedDay.day,
    );
  }

  /// One day of the grid: bold white on a teal circle when selected, a half
  /// teal circle for today, grey outside the data years.
  Widget _cell(DateTime day, {bool selected = false, bool today = false}) {
    final enabled = !day.isBefore(_firstDay) && !day.isAfter(_lastDay);
    return Center(
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: selected || today
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? IosColors.teal
                    : IosColors.teal.withValues(alpha: .5),
              )
            : null,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: IosText.callout,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? Colors.white
                : (enabled
                      ? IosColors.primary(context)
                      : IosColors.secondary(context)),
          ),
        ),
      ),
    );
  }

  Widget _grid(String language) => TableCalendar(
    firstDay: _firstDay,
    lastDay: _lastDay,
    focusedDay: _focusedDay,
    currentDay: _now(),
    locale: language,
    calendarFormat: CalendarFormat.month,
    headerVisible: false,
    pageAnimationDuration: monthSlide,
    onCalendarCreated: (controller) => _monthPager = controller,
    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
    rowHeight: 48,
    daysOfWeekHeight: 28,
    // Months change on a swipe's release (_MonthSwipe), as on iOS; vertical
    // drags scroll the page.
    availableGestures: AvailableGestures.none,
    onDaySelected: (selectedDay, focusedDay) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _checkSelectedDayEkadashi();
    },
    onPageChanged: (focusedDay) {
      // A new month keeps the day of the month selected (its last day when
      // shorter), within the data years.
      final lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0).day;
      var day = DateTime(
        focusedDay.year,
        focusedDay.month,
        _selectedDay.day > lastDay ? lastDay : _selectedDay.day,
      );
      if (day.isBefore(_firstDay)) day = _firstDay;
      if (day.isAfter(_lastDay)) day = _lastDay;
      setState(() {
        _focusedDay = day;
        _selectedDay = day;
        // Swiping from December into January moves the year too.
        _selectedYear = day.year;
      });
      _checkSelectedDayEkadashi();
      _showsYear(day.year);
    },
    calendarStyle: const CalendarStyle(
      outsideDaysVisible: false,
      cellMargin: EdgeInsets.zero,
    ),
    calendarBuilders: CalendarBuilders(
      // Single letters ("S M T W T F S") in the app language.
      dowBuilder: (context, day) => Center(
        child: Text(
          DateFormat.EEEEE(language).format(day),
          style: TextStyle(
            fontSize: IosText.subheadline,
            fontWeight: FontWeight.w500,
            color: IosColors.primary(context),
          ),
        ),
      ),
      defaultBuilder: (context, day, _) => _cell(day),
      disabledBuilder: (context, day, _) => _cell(day),
      todayBuilder: (context, day, _) => _cell(day, today: true),
      selectedBuilder: (context, day, _) => _cell(day, selected: true),
      outsideBuilder: (context, day, _) => const SizedBox.shrink(),
      markerBuilder: (context, date, events) {
        final colors = <Color>[
          if ((_filter == CalendarFilter.all ||
                  _filter == CalendarFilter.ekadashi) &&
              _isEkadashiDay(date))
            IosColors.teal,
          if ((_filter == CalendarFilter.all ||
                  _filter == CalendarFilter.google) &&
              _entries.any(
                (e) =>
                    e.source == CalendarEntrySource.google && e.occursOn(date),
              ))
            IosColors.googleBlue,
          if ((_filter == CalendarFilter.all ||
                  _filter == CalendarFilter.custom) &&
              _entries.any(
                (e) =>
                    e.source == CalendarEntrySource.custom && e.occursOn(date),
              ))
            IosColors.customPurple,
        ];
        if (colors.isEmpty) return null;
        return Positioned(
          bottom: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, color) in colors.indexed) ...[
                if (index > 0) const SizedBox(width: 2),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  /// The selected day's Ekadashi (or "No Ekadashi on this day" under the
  /// Ekadashi filter) and its Google and custom entries.
  Widget _selectedDaySection(LanguageService lang) {
    final ekadashi = _selectedEkadashi;
    final parana = EkadashiCalendarDay(
      widget.ekadashiList,
      _selectedDay,
      _settings?.city.timeZoneId ?? widget.currentTimezone ?? 'IST',
    ).parana;
    final showEkadashi =
        _filter == CalendarFilter.all || _filter == CalendarFilter.ekadashi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ekadashi != null && showEkadashi)
          _ekadashiCard(ekadashi)
        else if (_filter == CalendarFilter.ekadashi && parana.isEmpty)
          Text(
            lang.translate('no_ekadashi'),
            key: const Key('calendar_no_ekadashi'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.subheadline,
              color: IosColors.secondary(context),
            ),
          ),
        if (showEkadashi)
          for (final event in parana) _ekadashiCard(event, paranaOnly: true),
        if (_filter != CalendarFilter.ekadashi) ...[
          if (ekadashi != null && showEkadashi) const SizedBox(height: 10),
          DayEntriesList(
            // An Ekadashi is the day's entry: no "No entries for this day".
            showEmptyText:
                (ekadashi == null && parana.isEmpty) || !showEkadashi,
            items: CalendarDayMerge.merge(
              day: _selectedDay,
              ekadashis: const [],
              entries: _entries,
              filter: _filter,
            ),
            onTap: (item) {
              if (item.editable) {
                _editEntry(
                  existing: _entries.firstWhere((e) => e.id == item.entryId),
                );
              }
            },
            onDeleteCustom: (item) async {
              try {
                await _repo.delete(item.entryId!);
                await _reloadEntries();
                EventReminderService.instance.changed();
              } catch (_) {
                _showMessage('storage_failed');
              }
            },
          ),
        ],
      ],
    );
  }

  /// A swipe to the left shows the next month, to the right the previous
  /// one, within the data years (the grid's own paging).
  void _swipeMonth(int direction) {
    if (direction > 0 ? _isLastMonth : _isFirstMonth) return;
    if (direction > 0) {
      _monthPager?.nextPage(duration: monthSlide, curve: Curves.easeInOut);
    } else {
      _monthPager?.previousPage(duration: monthSlide, curve: Curves.easeInOut);
    }
  }

  /// The selected day's Ekadashi with its fasting times and View Details
  /// (CalendarEkadashiCard); recording happens on Home and Journey.
  Widget _ekadashiCard(EkadashiDate ekadashi, {bool paranaOnly = false}) {
    final lang = Provider.of<LanguageService>(context);
    final tracker = Provider.of<VratTrackerService>(context);
    final language = lang.currentLocale.languageCode;
    final status = tracker.getRecordByUid(ekadashi.occurrenceUid)?.status;
    final pill = switch (status) {
      ObservanceStatus.observed => (
        IosColors.green(context),
        AppIcons.statusObserved,
      ),
      ObservanceStatus.partial => (IosColors.partial, AppIcons.statusPartial),
      ObservanceStatus.missed => (IosColors.missed, AppIcons.statusMissed),
      _ => null,
    };
    final breakTime = AppStrings.localizeClock(
      ekadashi.fastBreakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), ''),
      language,
    );
    final line = TextStyle(
      fontSize: IosText.subheadline,
      color: IosColors.primary(context),
    );
    return GlassPanel(
      key: const Key('calendar_ekadashi_card'),
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ekadashi.name,
                  style: const TextStyle(
                    fontSize: IosText.headline,
                    fontWeight: FontWeight.w600,
                    color: IosColors.teal,
                  ),
                ),
              ),
              if (tracker.trackerEnabled && pill != null) ...[
                const SizedBox(width: 8),
                StatusPill(
                  text: lang.translate(status!.name),
                  color: pill.$1,
                  icon: pill.$2,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          LifecycleBuilder(
            event: ekadashi,
            timezone:
                _settings?.city.timeZoneId ?? widget.currentTimezone ?? 'IST',
            builder: (context, state) => Text(
              state.label(language),
              key: const Key('calendar_lifecycle_status'),
              style: line.copyWith(color: IosColors.teal),
            ),
          ),
          if (!paranaOnly)
            Text(
              '${lang.translate('start_fasting')}: '
              '${AppStrings.localizeClock(ekadashi.fastStartTime, language)}',
              style: line,
            ),
          const SizedBox(height: 10),
          Text('${lang.translate('break_fasting')}: $breakTime', style: line),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('calendar_view_details'),
              style: IosButtons.prominent(vertical: 10),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailsScreen(
                    ekadashi: ekadashi,
                    timezone: widget.currentTimezone,
                  ),
                ),
              ),
              child: Text(
                lang.translate('view_details'),
                style: const TextStyle(
                  fontSize: IosText.footnote,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pages the calendar by month on a horizontal swipe outside the grid
/// (docs/ROADMAP.md Phase 9); vertical drags still scroll the page.
class _MonthSwipe extends StatelessWidget {
  const _MonthSwipe({required this.onSwipe, required this.child});

  /// 1 for the next month, -1 for the previous one.
  final ValueChanged<int> onSwipe;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragEnd: (details) {
      final velocity = details.primaryVelocity ?? 0;
      if (velocity.abs() < 200) return;
      onSwipe(velocity < 0 ? 1 : -1);
    },
    child: child,
  );
}
