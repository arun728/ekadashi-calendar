import 'premium_screen.dart';
import '../services/premium_service.dart';
import '../widgets/glass_tube.dart';
import 'dart:async';
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
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import 'package:intl/intl.dart';
import 'details_screen.dart';
import '../services/vrat_tracker_service.dart';
import '../models/vrat_tracker_models.dart';
import 'vrat_tracker/record_vrat_dialog.dart';
import 'vrat_tracker/achievement_unlock_dialog.dart';

class CalendarScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;
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
  List<int> get _years =>
      (widget.ekadashiList.map((e) => e.date.year).toSet().toList()..sort());
  late int _selectedYear;
  DateTime get _firstDay => DateTime(_selectedYear, 1, 1);
  DateTime get _lastDay => DateTime(_selectedYear, 12, 31);

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  EkadashiDate? _selectedEkadashi;
  late final CalendarEntryRepository _repo;
  late final GoogleCalendarService _google;
  List<CalendarEntry> _entries = [];
  CalendarFilter _filter = CalendarFilter.ekadashi;
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
    if (_repoReady) _reloadEntries();
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
    // Ensure focused day is within valid range
    final now = _now();
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
    _premium?.removeListener(_onPremiumChanged);
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

  Future<void> _editEntry({CalendarEntry? existing}) async {
    final result = await AddEditEntrySheet.show(
      context,
      initialDay: _selectedDay,
      existing: existing,
    );
    if (result == null) return;
    try {
      await _repo.upsert(result);
      await _reloadEntries();
      if (mounted) setState(() => _filter = CalendarFilter.custom);
    } catch (_) {
      _showMessage('storage_failed');
    }
  }

  void _showMessage(String key, {List<String>? args, bool upsell = false}) {
    if (!mounted) return;
    final lang = context.read<LanguageService>();
    // The newest Calendar status replaces any message still showing.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            args == null
                ? lang.translate(key)
                : lang.translateWithArgs(key, args),
          ),
          action: upsell
              ? SnackBarAction(
                  label: lang.translate('premium_title'),
                  onPressed: () => openPremium(
                    context,
                    currentTimezone: widget.currentTimezone ?? 'IST',
                  ),
                )
              : null,
        ),
      );
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  bool _isPremium() => context.read<PremiumService?>()?.isPremium == true;

  /// Opens the paywall; true when the user now has premium.
  Future<bool> _unlockPremium() async {
    await openPremium(
      context,
      currentTimezone: widget.currentTimezone ?? 'IST',
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
      if (!await _unlockPremium()) return;
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
      if (!premium &&
          googleIdToken != null &&
          await _registry!.isUsed(googleIdToken)) {
        // This Google account used its free sync before (e.g. before a
        // reinstall or on another phone).
        await prefs.setBool(CalendarScreen.freeSyncUsedKey, true);
        if (!mounted) return;
        setState(() => _syncing = false);
        if (!await _unlockPremium()) return;
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
      if (mounted) setState(() => _filter = CalendarFilter.google);
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

  void resetToToday() {
    final now = DateTime.now();
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

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (_repoError)
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(lang.translate('storage_failed')),
                trailing: TextButton(
                  onPressed: _initRepo,
                  child: Text(lang.translate('retry')),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: GlassTube(
                  key: const Key('calendar_actions_tube'),
                  optionCount: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        key: const Key('add_calendar_entry'),
                        tooltip: lang.translate('add_entry'),
                        onPressed: _repoReady ? () => _editEntry() : null,
                        icon: const Icon(
                          Icons.add,
                          color: GlassTubeColors.teal,
                        ),
                      ),
                      if (_syncing)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ...[
                        IconButton(
                          key: const Key('import_google_year'),
                          tooltip: lang.translate('sync_google'),
                          onPressed: _repoReady && !_syncing ? _syncYear : null,
                          icon: const Icon(
                            Icons.sync,
                            color: GlassTubeColors.teal,
                          ),
                        ),
                        IconButton(
                          key: const Key('disconnect_google'),
                          tooltip: lang.translate('disconnect_google'),
                          onPressed: _repoReady && !_syncing
                              ? _disconnectGoogle
                              : null,
                          icon: const Icon(
                            Icons.link_off,
                            color: GlassTubeColors.teal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: CalendarFilterBar(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(lang.translate('year')),
                  DropdownButton<int>(
                    key: const Key('calendar_year_selector'),
                    value: _selectedYear,
                    items: [
                      for (final year
                          in _years.isEmpty ? [_selectedYear] : _years)
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (year) {
                      if (year == null) return;
                      setState(() {
                        _selectedYear = year;
                        _focusedDay = DateTime(year, _focusedDay.month, 1);
                        _selectedDay = _focusedDay;
                      });
                      _checkSelectedDayEkadashi();
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: GlassTube(
                key: const Key('calendar_month_tube'),
                optionCount: 2,
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('calendar_previous_month'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).previousMonthTooltip,
                      color: GlassTubeColors.teal,
                      onPressed: _isFirstMonth
                          ? null
                          : () => _monthPager?.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM(
                          lang.currentLocale.languageCode,
                        ).format(_focusedDay),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      key: const Key('calendar_next_month'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).nextMonthTooltip,
                      color: GlassTubeColors.teal,
                      onPressed: _isLastMonth
                          ? null
                          : () => _monthPager?.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Keep the selected-day status visible before the grid on short screens.
          if (_selectedEkadashi == null && _filter == CalendarFilter.ekadashi)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  lang.translate('no_ekadashi'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: TableCalendar(
              key: ValueKey(_selectedYear),
              firstDay: _firstDay,
              lastDay: _lastDay,
              focusedDay: _focusedDay,
              locale: lang.currentLocale.languageCode,
              calendarFormat: CalendarFormat.month,
              headerVisible: false,
              onCalendarCreated: (controller) => _monthPager = controller,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                // Force English Month Name (January 2026) regardless of locale
                titleTextFormatter: (date, locale) => DateFormat.yMMMM(
                  lang.currentLocale.languageCode,
                ).format(date),
                // Custom chevrons with grey color at boundaries
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: _isFirstMonth ? Colors.grey.shade500 : tealColor,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: _isLastMonth ? Colors.grey.shade500 : tealColor,
                ),
              ),
              // Weekdays matching the Header (Month Year) style (w500)
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Theme.of(context).textTheme.titleMedium?.color,
                  fontWeight: FontWeight.w500, // Match header's medium weight
                  fontSize: 14,
                ),
                weekendStyle: TextStyle(
                  color: Theme.of(context).textTheme.titleMedium?.color,
                  fontWeight: FontWeight.w500, // Match header's medium weight
                  fontSize: 14,
                ),
              ),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              // Increase row height to prevent overlap
              rowHeight: 48,
              daysOfWeekHeight: 28,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });

                final selected = DateTime(
                  selectedDay.year,
                  selectedDay.month,
                  selectedDay.day,
                );
                EkadashiDate? found;

                for (var ekadashi in widget.ekadashiList) {
                  final ekadashiDate = DateTime(
                    ekadashi.date.year,
                    ekadashi.date.month,
                    ekadashi.date.day,
                  );
                  if (ekadashiDate == selected) {
                    found = ekadashi;
                    break;
                  }
                }
                setState(() => _selectedEkadashi = found);
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: tealColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: tealColor,
                  shape: BoxShape.circle,
                ),
                // Adjust cell margins for better spacing
                cellMargin: const EdgeInsets.all(4),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final colors = <Color>[
                    if ((_filter == CalendarFilter.all ||
                            _filter == CalendarFilter.ekadashi) &&
                        _isEkadashiDay(date))
                      tealColor,
                    if ((_filter == CalendarFilter.all ||
                            _filter == CalendarFilter.google) &&
                        _entries.any(
                          (e) =>
                              e.source == CalendarEntrySource.google &&
                              e.occursOn(date),
                        ))
                      const Color(CalendarMarkerColors.googleBlue),
                    if ((_filter == CalendarFilter.all ||
                            _filter == CalendarFilter.custom) &&
                        _entries.any(
                          (e) =>
                              e.source == CalendarEntrySource.custom &&
                              e.occursOn(date),
                        ))
                      const Color(CalendarMarkerColors.customPurple),
                  ];
                  if (colors.isNotEmpty) {
                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final color in colors)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  return null;
                },
              ),

              availableGestures: AvailableGestures.all,
            ),
          ),

          // Spacer between calendar and details
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Simplified ekadashi details - fills remaining space
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (_selectedEkadashi != null &&
                    (_filter == CalendarFilter.all ||
                        _filter == CalendarFilter.ekadashi))
                  _buildSimpleEkadashiCard(_selectedEkadashi!),
                if (_filter != CalendarFilter.ekadashi)
                  DayEntriesList(
                    items: CalendarDayMerge.merge(
                      day: _selectedDay,
                      ekadashis: const [],
                      entries: _entries,
                      filter: _filter,
                    ),
                    onTap: (item) {
                      if (item.editable) {
                        _editEntry(
                          existing: _entries.firstWhere(
                            (e) => e.id == item.entryId,
                          ),
                        );
                      }
                    },
                    onDeleteCustom: (item) async {
                      try {
                        await _repo.delete(item.entryId!);
                        await _reloadEntries();
                      } catch (_) {
                        _showMessage('storage_failed');
                      }
                    },
                  ),
                // Add bottom padding to ensure content isn't cut off on very small screens
                SizedBox(height: 88 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleEkadashiCard(EkadashiDate ekadashi) {
    final lang = Provider.of<LanguageService>(context);
    final tracker = Provider.of<VratTrackerService>(context);
    const tealColor = Color(0xFF00A19B);

    final record = tracker.getRecordByUid(ekadashi.occurrenceUid);
    final status = record?.status ?? ObservanceStatus.unrecorded;

    Color? statusColor;
    String? statusLabel;
    IconData? statusIcon;

    if (tracker.trackerEnabled) {
      switch (status) {
        case ObservanceStatus.observed:
          statusColor = Colors.green;
          statusLabel = lang.translate('observed');
          statusIcon = Icons.check_circle;
          break;
        case ObservanceStatus.partial:
          statusColor = Colors.amber.shade700;
          statusLabel = lang.translate('partial');
          statusIcon = Icons.adjust;
          break;
        case ObservanceStatus.missed:
          statusColor = Colors.red.shade400;
          statusLabel = lang.translate('missed');
          statusIcon = Icons.highlight_off;
          break;
        case ObservanceStatus.unrecorded:
          statusColor = Colors.grey;
          statusLabel = lang.translate('not_recorded');
          statusIcon = Icons.help_outline;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ekadashi name
              Text(
                ekadashi.name,
                style: const TextStyle(
                  color: tealColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              // Subtle Vrat status indicator on calendar (Requirement 18 - NO CHECKBOX)
              if (tracker.trackerEnabled &&
                  statusLabel != null &&
                  statusColor != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      // Wraps on narrow phones with large text instead of
                      // overflowing the card.
                      Flexible(
                        child: Text(
                          statusLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Show timezone info if available
              if (widget.currentTimezone != null &&
                  widget.currentTimezone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.currentTimezone!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
              const SizedBox(height: 12),

              // Action buttons: View Details and Record Vrat (Requirement 17)
              GlassOptionGroup(
                key: const Key('calendar_card_actions_tube'),
                optionCount: tracker.trackerEnabled ? 2 : 1,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                ekadashi: ekadashi,
                                timezone: widget.currentTimezone,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tracker.trackerEnabled
                              ? Colors.transparent
                              : tealColor,
                          foregroundColor: tracker.trackerEnabled
                              ? GlassTubeColors.teal
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          lang.translate('view_details'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (tracker.trackerEnabled) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final unlocks = await RecordVratDialog.show(
                              context,
                              ekadashi: ekadashi,
                              allOccurrences: widget.ekadashiList,
                              currentTimezone: widget.currentTimezone ?? 'IST',
                            );
                            if (unlocks != null &&
                                unlocks.isNotEmpty &&
                                mounted) {
                              for (final u in unlocks) {
                                await AchievementUnlockDialog.show(context, u);
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: statusColor ?? tealColor,
                            side: BorderSide(color: statusColor ?? tealColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            record != null
                                ? lang.translate('edit_record')
                                : lang.translate('record_vrat'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
