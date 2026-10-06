import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../services/google_calendar_service.dart';

/// Returned by the picker when the user wants another Google account.
const switchGoogleAccountResult = ['__switch_google_account__'];

/// Multi-select which Google calendars to import from [accountEmail].
Future<List<String>?> showGoogleCalendarPickerSheet({
  required BuildContext context,
  required List<GoogleCalendarInfo> calendars,
  required List<String> initiallySelected,
  String? accountEmail,
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
      accountEmail: accountEmail,
    ),
  );
}

class _GoogleCalendarPickerBody extends StatefulWidget {
  final List<GoogleCalendarInfo> calendars;
  final List<String> initiallySelected;
  final String? accountEmail;

  const _GoogleCalendarPickerBody({
    required this.calendars,
    required this.initiallySelected,
    this.accountEmail,
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
    _selected = widget.initiallySelected
        .where((id) => widget.calendars.any((c) => c.id == id))
        .toSet();
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
    final lang = context.watch<LanguageService>();
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
            Text(
              lang.translate('choose_calendars'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              lang.translate('choose_calendars_help'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
            if (widget.accountEmail != null)
              Row(
                children: [
                  const Icon(Icons.account_circle_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.accountEmail!,
                      key: const Key('google_picker_account'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    key: const Key('google_switch_account'),
                    onPressed: () =>
                        Navigator.pop(context, switchGoogleAccountResult),
                    child: Text(lang.translate('switch_google_account')),
                  ),
                ],
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
                    subtitle: c.primary
                        ? Text(lang.translate('primary_calendar'))
                        : null,
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
              child: Text(lang.translate('import_selected')),
            ),
          ],
        ),
      ),
    );
  }
}
