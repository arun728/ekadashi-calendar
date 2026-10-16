import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../widgets/ios_style.dart';
import '../../widgets/settings_group.dart';
import '../../widgets/time_picker.dart';
import '../../models/calendar_entry.dart';

/// Add or edit a custom entry (EntryEditorView.swift): an iOS sheet with
/// Cancel and Save, a title, All day, start and end dates and times (an
/// entry may run over several days; the end may equal the start) and notes.
///
/// Stored as before: timed entries in local time; all-day entries as local
/// midnights with an exclusive end.
class AddEditEntrySheet extends StatefulWidget {
  final DateTime initialDay;
  final CalendarEntry? existing;

  /// Stores the entry; false keeps the sheet open (a storage error).
  final Future<bool> Function(CalendarEntry entry)? onSave;

  const AddEditEntrySheet({
    super.key,
    required this.initialDay,
    this.existing,
    this.onSave,
  });

  /// Shows the sheet; the saved entry, or null when cancelled.
  static Future<CalendarEntry?> show(
    BuildContext context, {
    required DateTime initialDay,
    CalendarEntry? existing,
    Future<bool> Function(CalendarEntry entry)? onSave,
  }) {
    return showAppSheet<CalendarEntry>(
      context,
      large: false,
      builder: (_) => AddEditEntrySheet(
        initialDay: initialDay,
        existing: existing,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditEntrySheet> createState() => _AddEditEntrySheetState();
}

class _AddEditEntrySheetState extends State<AddEditEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _allDay = false;
  bool _invalid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _allDay = e.isAllDay;
      final start = e.localStart, end = e.localEnd;
      if (e.isAllDay) {
        // All-day ends are exclusive; the picker shows the last day.
        _start = DateTime(start.year, start.month, start.day, 9);
        _end = DateTime(end.year, end.month, end.day - 1, 9);
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _start = start;
        _end = end;
      }
    } else {
      final day = widget.initialDay;
      _start = DateTime(day.year, day.month, day.day, 9);
      _end = DateTime(day.year, day.month, day.day, 10);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _language =>
      context.read<LanguageService>().currentLocale.languageCode;

  static DateTime _withDate(DateTime time, DateTime date) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  static DateTime _withTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  /// A later start moves the end along, as the iOS end picker starts at the
  /// start.
  void _setStart(DateTime value) => setState(() {
    _start = value;
    if (_end.isBefore(_start)) _end = _start;
  });

  void _setEnd(DateTime value) =>
      setState(() => _end = value.isBefore(_start) ? _start : value);

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) =>
      showDatePicker(
        context: context,
        useRootNavigator: true,
        initialDate: initial,
        firstDate: first ?? DateTime(1900),
        lastDate: DateTime(2100, 12, 31),
        locale: Locale(_language),
      );

  Future<void> _pickStartDate() async {
    final date = await _pickDate(_start);
    if (date != null) _setStart(_withDate(_start, date));
  }

  Future<void> _pickEndDate() async {
    final first = DateTime(_start.year, _start.month, _start.day);
    final date = await _pickDate(
      _end.isBefore(first) ? first : _end,
      first: first,
    );
    if (date != null) _setEnd(_withDate(_end, date));
  }

  Future<void> _pickStartTime() async {
    final time = await pickTime(context, TimeOfDay.fromDateTime(_start));
    if (time != null) _setStart(_withTime(_start, time));
  }

  Future<void> _pickEndTime() async {
    final time = await pickTime(context, TimeOfDay.fromDateTime(_end));
    if (time != null) _setEnd(_withTime(_end, time));
  }

  /// The entry as stored, or null when the title is empty or the end is
  /// before the start.
  CalendarEntry? _entry() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return null;
    DateTime startAt;
    DateTime endAt;
    if (_allDay) {
      startAt = DateTime(_start.year, _start.month, _start.day);
      final last = DateTime(_end.year, _end.month, _end.day);
      if (last.isBefore(startAt)) return null;
      endAt = DateTime(last.year, last.month, last.day + 1);
    } else {
      startAt = _start;
      endAt = _end;
      if (endAt.isBefore(startAt)) return null;
    }
    final notes = _notesCtrl.text.trim();
    return CalendarEntry(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: title,
      notes: notes.isEmpty ? null : notes,
      startAt: startAt,
      endAt: endAt,
      isAllDay: _allDay,
      source: CalendarEntrySource.custom,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final entry = _entry();
    if (entry == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _invalid = false;
      _saving = true;
    });
    final saved = await (widget.onSave?.call(entry) ?? Future.value(true));
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final language = lang.currentLocale.languageCode;
    final primary = IosColors.primary(context);
    final bodyStyle = TextStyle(fontSize: IosText.body, color: primary);
    final hintStyle = TextStyle(
      fontSize: IosText.body,
      color: IosColors.tertiary(context),
    );
    InputDecoration field(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      border: InputBorder.none,
      isCollapsed: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
    );
    final date = DateFormat('d MMM yyyy', language);
    Widget whenRow(
      String label,
      DateTime value, {
      required Key dateKey,
      required Key timeKey,
      required VoidCallback pickDate,
      required VoidCallback pickTime,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: bodyStyle)),
          // Long dates shrink rather than overflow.
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: _Pill(
                key: dateKey,
                text: date.format(value),
                onTap: pickDate,
              ),
            ),
          ),
          if (!_allDay) ...[
            const SizedBox(width: 6),
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: _Pill(
                  key: timeKey,
                  text: AppStrings.clock(value.hour, value.minute, language),
                  onTap: pickTime,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetBar(
            title: lang.translate(
              widget.existing == null ? 'add_entry' : 'edit_entry',
            ),
            leading: BarTextButton(
              key: const Key('entry_cancel'),
              label: lang.translate('cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            trailing: BarTextButton(
              key: const Key('save_entry'),
              label: lang.translate('save'),
              bold: true,
              onPressed: _saving ? null : _save,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          key: const Key('entry_title'),
                          controller: _titleCtrl,
                          style: bodyStyle,
                          cursorColor: IosColors.teal,
                          decoration: field(lang.translate('entry_title')),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SettingsSeparator(),
                      InkWell(
                        key: const Key('entry_all_day'),
                        onTap: () => setState(() => _allDay = !_allDay),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lang.translate('all_day'),
                                  style: bodyStyle,
                                ),
                              ),
                              Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(platform: TargetPlatform.iOS),
                                child: Switch.adaptive(
                                  value: _allDay,
                                  activeTrackColor: IosColors.teal,
                                  onChanged: (v) => setState(() => _allDay = v),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SettingsSeparator(),
                      whenRow(
                        lang.translate('entry_starts'),
                        _start,
                        dateKey: const Key('entry_start_date'),
                        timeKey: const Key('entry_start_time'),
                        pickDate: _pickStartDate,
                        pickTime: _pickStartTime,
                      ),
                      const SettingsSeparator(),
                      whenRow(
                        lang.translate('entry_ends'),
                        _end,
                        dateKey: const Key('entry_end_date'),
                        timeKey: const Key('entry_end_time'),
                        pickDate: _pickEndDate,
                        pickTime: _pickEndTime,
                      ),
                      const SettingsSeparator(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          key: const Key('entry_notes'),
                          controller: _notesCtrl,
                          style: bodyStyle,
                          cursorColor: IosColors.teal,
                          decoration: field(lang.translate('entry_notes')),
                          minLines: 2,
                          maxLines: 5,
                        ),
                      ),
                    ],
                  ),
                  if (_invalid)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        lang.translate('invalid_entry'),
                        style: TextStyle(
                          fontSize: IosText.footnote,
                          color: IosColors.red(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grey capsule of an iOS compact date or time picker.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0x3D767680) : const Color(0x1F767680),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: IosText.body,
              color: IosColors.primary(context),
            ),
          ),
        ),
      ),
    );
  }
}
