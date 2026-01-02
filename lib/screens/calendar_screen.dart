import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/ekadashi_service.dart';
import 'details_screen.dart';

class CalendarScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;
  const CalendarScreen({super.key, required this.ekadashiList});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  void resetToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00A19B);

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2026, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.sunday,

          // Reverted to 52 to fix "days disappeared" issue
          rowHeight: 52,
          // Explicitly set header height to prevent clipping
          daysOfWeekHeight: 30,

          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF00A19B)),
            rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF00A19B)),
          ),

          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Color(0xFF00A19B),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: tealColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Color(0xFF00A19B),
              shape: BoxShape.circle,
            ),
            markerSize: 8.0,
            cellMargin: EdgeInsets.all(6.0),
          ),

          eventLoader: (day) {
            final isEkadashi = widget.ekadashiList.any((e) =>
            e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day
            );
            return isEkadashi ? [true] : [];
          },

          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),

        const SizedBox(height: 20),

        Expanded(
          child: _buildEventList(),
        ),
      ],
    );
  }

  Widget _buildEventList() {
    if (_selectedDay == null) return const SizedBox();

    final events = widget.ekadashiList.where((e) =>
    e.date.year == _selectedDay!.year &&
        e.date.month == _selectedDay!.month &&
        e.date.day == _selectedDay!.day
    ).toList();

    if (events.isEmpty) {
      return const Center(child: Text("No Ekadashi on this day."));
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final ekadashi = events[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailsScreen(ekadashi: ekadashi),
                ),
              );
            },
            child: ListTile(
              leading: const Icon(Icons.event, color: Color(0xFF00A19B)),
              title: Text(ekadashi.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(ekadashi.fastStartTime),
            ),
          ),
        );
      },
    );
  }
}