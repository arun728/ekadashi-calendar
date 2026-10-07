import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../models/calendar_entry.dart';

class AddEditEntrySheet extends StatefulWidget {
  final DateTime initialDay;
  final CalendarEntry? existing;

  const AddEditEntrySheet({super.key, required this.initialDay, this.existing});

  static Future<CalendarEntry?> show(
    BuildContext context, {
    required DateTime initialDay,
    CalendarEntry? existing,
  }) {
    return showModalBottomSheet<CalendarEntry>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          AddEditEntrySheet(initialDay: initialDay, existing: existing),
    );
  }

  @override
  State<AddEditEntrySheet> createState() => _AddEditEntrySheetState();
}

class _AddEditEntrySheetState extends State<AddEditEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _allDay = false;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _day = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
    if (e != null) {
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _allDay = e.isAllDay;
      final start = e.localStart, end = e.localEnd;
      _start = TimeOfDay(hour: start.hour, minute: start.minute);
      _end = TimeOfDay(hour: end.hour, minute: end.minute);
      _day = DateTime(start.year, start.month, start.day);
    } else {
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    DateTime startAt;
    DateTime endAt;
    if (_allDay) {
      startAt = _day;
      endAt = DateTime(_day.year, _day.month, _day.day + 1);
    } else {
      startAt = _combine(_day, _start);
      endAt = _combine(_day, _end);
      if (!endAt.isAfter(startAt)) {
        setState(() => _invalid = true);
        return;
      }
    }
    final entry = CalendarEntry(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: title,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      startAt: startAt,
      endAt: endAt,
      isAllDay: _allDay,
      source: CalendarEntrySource.custom,
      updatedAt: DateTime.now().toUtc(),
    );
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    const purple = Color(CalendarMarkerColors.customPurple);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.translate(
                widget.existing == null ? 'add_entry' : 'edit_entry',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: lang.translate('entry_title'),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: widget.existing == null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(lang.translate('all_day')),
              value: _allDay,
              activeThumbColor: purple,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            if (!_allDay) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lang.translate('entry_starts')),
                trailing: Text(_start.format(context)),
                onTap: _pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lang.translate('entry_ends')),
                trailing: Text(_end.format(context)),
                onTap: _pickEnd,
              ),
            ],
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: lang.translate('entry_notes'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_invalid)
              Text(
                lang.translate('invalid_entry'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(lang.translate('save')),
            ),
          ],
        ),
      ),
    );
  }
}
