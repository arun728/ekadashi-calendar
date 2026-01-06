import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import 'details_screen.dart';

class CalendarScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;

  const CalendarScreen({super.key, required this.ekadashiList});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  // Fixed date range: Jan 2025 to Dec 2026
  static final DateTime _firstDay = DateTime(2025, 1, 1);
  static final DateTime _lastDay = DateTime(2026, 12, 31);

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  EkadashiDate? _selectedEkadashi;

  @override
  void initState() {
    super.initState();
    // Ensure focused day is within valid range
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
    _checkSelectedDayEkadashi();
  }

  void _checkSelectedDayEkadashi() {
    final selected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    for (var ekadashi in widget.ekadashiList) {
      final ekadashiDate = DateTime(ekadashi.date.year, ekadashi.date.month, ekadashi.date.day);
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
      final ed = DateTime(ekadashi.date.year, ekadashi.date.month, ekadashi.date.day);
      if (ed == d) return true;
    }
    return false;
  }

  // Check if we're at the first month
  bool get _isFirstMonth {
    return _focusedDay.year == _firstDay.year && _focusedDay.month == _firstDay.month;
  }

  // Check if we're at the last month
  bool get _isLastMonth {
    return _focusedDay.year == _lastDay.year && _focusedDay.month == _lastDay.month;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

    return Column(
      children: [
        TableCalendar(
          firstDay: _firstDay,
          lastDay: _lastDay,
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          // Increase row height to prevent overlap
          rowHeight: 48,
          daysOfWeekHeight: 28,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });

            final selected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
            EkadashiDate? found;

            for (var ekadashi in widget.ekadashiList) {
              final ekadashiDate = DateTime(ekadashi.date.year, ekadashi.date.month, ekadashi.date.day);
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
              color: tealColor.withOpacity(0.5),
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
              if (_isEkadashiDay(date)) {
                return Positioned(
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: tealColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }
              return null;
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
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
          availableGestures: AvailableGestures.all,
        ),

        const SizedBox(height: 16),

        // Simplified ekadashi details - just name and button
        if (_selectedEkadashi != null)
          _buildSimpleEkadashiCard(_selectedEkadashi!)
        else
          Expanded(
            child: Center(
              child: Text(
                lang.translate('no_ekadashi'),
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSimpleEkadashiCard(EkadashiDate ekadashi) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

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
              const SizedBox(height: 12),
              // View Details button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailsScreen(ekadashi: ekadashi),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    lang.translate('view_details'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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