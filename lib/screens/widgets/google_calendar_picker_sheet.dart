import 'package:flutter/material.dart';
import '../../services/google_calendar_service.dart';

/// Multi-select which Google calendars to import.
Future<List<String>?> showGoogleCalendarPickerSheet({
  required BuildContext context,
  required List<GoogleCalendarInfo> calendars,
  required List<String> initiallySelected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _GoogleCalendarPickerBody(
      calendars: calendars,
      initiallySelected: initiallySelected,
    ),
  );
}

class _GoogleCalendarPickerBody extends StatefulWidget {
  final List<GoogleCalendarInfo> calendars;
  final List<String> initiallySelected;

  const _GoogleCalendarPickerBody({
    required this.calendars,
    required this.initiallySelected,
  });

  @override
  State<_GoogleCalendarPickerBody> createState() =>
      _GoogleCalendarPickerBodyState();
}

class _GoogleCalendarPickerBodyState extends State<_GoogleCalendarPickerBody> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
    if (_selected.isEmpty) {
      for (final c in widget.calendars) {
        if (c.primary) _selected.add(c.id);
      }
      if (_selected.isEmpty && widget.calendars.isNotEmpty) {
        _selected.add(widget.calendars.first.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Calendars to sync',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Holidays and other calendars are separate from Primary. Select all you want to import.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.calendars.length,
                itemBuilder: (context, i) {
                  final c = widget.calendars[i];
                  final checked = _selected.contains(c.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(c.id);
                        } else {
                          _selected.remove(c.id);
                        }
                      });
                    },
                    title: Text(c.summary),
                    subtitle: c.primary ? const Text('Primary') : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF4285F4),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
              ),
              child: const Text('Sync selected'),
            ),
          ],
        ),
      ),
    );
  }
}
