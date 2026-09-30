
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import '../models/calendar_entry.dart';
import '../models/calendar_day_merge.dart';
import '../data/calendar_entry_repository.dart';
import '../data/sqflite_calendar_entry_repository.dart';
import 'details_screen.dart';
import 'widgets/calendar_filter_bar.dart';
import 'widgets/day_entries_list.dart';
import 'widgets/add_edit_entry_sheet.dart';
import '../services/google_calendar_service.dart';
import '../services/google_calendar_prefs.dart';
import 'widgets/google_calendar_picker_sheet.dart';

const kEkadashiTeal = Color(0xFF00A19B);

class CalendarScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;
  final String? currentTimezone;
  final CalendarEntryRepository? repository;
  final GoogleCalendarService? googleService;

  const CalendarScreen({
    super.key,
    required this.ekadashiList,
    this.currentTimezone,
    this.repository,
    this.googleService,
  });

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  static final DateTime _firstDay = DateTime(2027, 1, 1);
  static final DateTime _lastDay = DateTime(2027, 12, 31);

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  EkadashiDate? _selectedEkadashi;

  CalendarFilter _filter = CalendarDayMerge.defaultFilter;
  List<CalendarEntry> _entries = [];
  late final CalendarEntryRepository _repo;
  bool _repoReady = false;
  bool _syncing = false;

  static const _teal = Color(CalendarMarkerColors.ekadashiTeal);
  static const _blue = Color(CalendarMarkerColors.googleBlue);
  static const _purple = Color(CalendarMarkerColors.customPurple);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
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
    _repo = widget.repository ?? SqfliteCalendarEntryRepository();
    _checkSelectedDayEkadashi();
    _initRepo();
  }

  Future<void> _initRepo() async {
    try {
      await _repo.init();
      final all = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _entries = all;
        _repoReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _repoReady = true);
    }
  }

  Future<void> _reloadEntries() async {
    final all = await _repo.getAll();
    if (!mounted) return;
    setState(() => _entries = all);
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ekadashiList != oldWidget.ekadashiList ||
        widget.currentTimezone != oldWidget.currentTimezone) {
      _checkSelectedDayEkadashi();
    }
  }

  void _checkSelectedDayEkadashi() {
    final selected =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    for (var ekadashi in widget.ekadashiList) {
      final ekadashiDate = DateTime(
          ekadashi.date.year, ekadashi.date.month, ekadashi.date.day);
      if (ekadashiDate == selected) {
        setState(() => _selectedEkadashi = ekadashi);
        return;
      }
    }
    setState(() => _selectedEkadashi = null);
  }

  void resetToToday() {
    final now = DateTime.now();
    DateTime targetDay;
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
          ekadashi.date.year, ekadashi.date.month, ekadashi.date.day);
      if (ed == d) return true;
    }
    return false;
  }

  List<CalendarEntry> _entriesOn(DateTime day) =>
      _entries.where((e) => e.occursOn(day)).toList();

  bool get _isFirstMonth =>
      _focusedDay.year == _firstDay.year &&
      _focusedDay.month == _firstDay.month;

  bool get _isLastMonth =>
      _focusedDay.year == _lastDay.year &&
      _focusedDay.month == _lastDay.month;

  List<DayListItem> _mergedForSelectedDay() {
    final day =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final ekas = <({String name, String? description})>[];
    if (_selectedEkadashi != null) {
      ekas.add((
        name: _selectedEkadashi!.name,
        description: _selectedEkadashi!.description,
      ));
    }
    return CalendarDayMerge.merge(
      day: day,
      ekadashis: ekas,
      entries: _entries,
      filter: _filter,
    );
  }

  Future<void> _onAddEntry() async {
    final result = await AddEditEntrySheet.show(
      context,
      initialDay: _selectedDay,
    );
    if (result == null) return;
    await _repo.upsert(result);
    await _reloadEntries();
  }

  Future<void> _onEditCustom(DayListItem item) async {
    if (!item.editable || item.entryId == null) return;
    final matches = _entries.where((e) => e.id == item.entryId).toList();
    final existing = matches.isEmpty ? null : matches.first;
    if (existing == null) return;
    final result = await AddEditEntrySheet.show(
      context,
      initialDay: _selectedDay,
      existing: existing,
    );
    if (result == null) return;
    await _repo.upsert(result);
    await _reloadEntries();
  }

  Future<void> _onDeleteCustom(DayListItem item) async {
    if (item.entryId == null) return;
    await _repo.delete(item.entryId!);
    await _reloadEntries();
  }

  Future<void> _onSyncGoogle() async {
    final svc = widget.googleService;
    if (svc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sync is not configured yet')),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final signedIn = await svc.isSignedIn() || await svc.signIn();
      if (!signedIn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in cancelled')),
        );
        return;
      }

      final calendars = await svc.listCalendars();
      if (!mounted) return;
      if (calendars.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Google calendars found')),
        );
        return;
      }

      final saved = await GoogleCalendarPrefs.loadSelectedIds();
      final chosen = await showGoogleCalendarPickerSheet(
        context: context,
        calendars: calendars,
        initiallySelected: saved,
      );
      if (chosen == null || chosen.isEmpty) return;

      await GoogleCalendarPrefs.saveSelectedIds(chosen);

      final min = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final max = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
      final n = await svc.syncImport(
        timeMin: min,
        timeMax: max,
        calendarIds: chosen,
      );
      await _reloadEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'No events in selected calendars for this month'
                : 'Imported $n Google event(s)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }


  void _onDayItemTap(DayListItem item) {
    if (item.kind == DayItemKind.ekadashi && _selectedEkadashi != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(
            ekadashi: _selectedEkadashi!,
            timezone: widget.currentTimezone,
          ),
        ),
      );
    } else if (item.editable) {
      _onEditCustom(item);
    }
  }

  List<Color> _markerColors(DateTime day) {
    final colors = <Color>[];
    final showE =
        _filter == CalendarFilter.all || _filter == CalendarFilter.ekadashi;
    final showG =
        _filter == CalendarFilter.all || _filter == CalendarFilter.google;
    final showC =
        _filter == CalendarFilter.all || _filter == CalendarFilter.custom;

    if (showE && _isEkadashiDay(day)) colors.add(_teal);
    final onDay = _entriesOn(day);
    if (showG && onDay.any((e) => e.source == CalendarEntrySource.google)) {
      colors.add(_blue);
    }
    if (showC && onDay.any((e) => e.source == CalendarEntrySource.custom)) {
      colors.add(_purple);
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final merged = _mergedForSelectedDay();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          articleFilterBar(),
          articleTableCalendar(),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                DateFormat.yMMMEd().format(_selectedDay),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DayEntriesList(
              items: merged,
              onTap: _onDayItemTap,
              onDeleteCustom: _onDeleteCustom,
            ),
          ),
          if (_filter == CalendarFilter.ekadashi &&
              _selectedEkadashi != null &&
              merged.isEmpty)
            SliverToBoxAdapter(
              child: _buildEkadashiCard(context, lang, _selectedEkadashi!),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _repoReady ? _onAddEntry : null,
        backgroundColor: _purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget articleFilterBar() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(
              children: [
                const Spacer(),
                if (_syncing)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Sync Google Calendar',
                    onPressed: _onSyncGoogle,
                    icon: const Icon(Icons.sync, color: Color(0xFF4285F4)),
                  ),
              ],
            ),
          ),
          CalendarFilterBar(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ],
      ),
    );
  }

  Widget articleTableCalendar() {
    return SliverToBoxAdapter(
      child: TableCalendar(
        firstDay: _firstDay,
        lastDay: _lastDay,
        focusedDay: _focusedDay,
        locale: 'en',
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextFormatter: (date, locale) =>
              DateFormat.yMMMM('en').format(date),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: _isFirstMonth ? Colors.grey.shade500 : kEkadashiTeal,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: _isLastMonth ? Colors.grey.shade500 : kEkadashiTeal,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          weekendStyle: TextStyle(
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        rowHeight: 52,
        daysOfWeekHeight: 28,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _checkSelectedDayEkadashi();
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            final colors = _markerColors(day);
            if (colors.isEmpty) return null;
            return Positioned(
              bottom: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: colors
                    .map((c) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                          ),
                        ))
                    .toList(),
              ),
            );
          },
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: kEkadashiTeal,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: kEkadashiTeal.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
      ),
    );
  }

  Widget _buildEkadashiCard(
      BuildContext context, LanguageService lang, EkadashiDate ekadashi) {
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
              Text(
                ekadashi.name,
                style: const TextStyle(
                  color: kEkadashiTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.currentTimezone != null &&
                  widget.currentTimezone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.currentTimezone!,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
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
                    backgroundColor: kEkadashiTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    lang.translate('view_details'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

