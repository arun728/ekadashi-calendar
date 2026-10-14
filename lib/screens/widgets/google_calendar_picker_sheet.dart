import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/material.dart';
import '../../services/google_calendar_service.dart';
import '../../widgets/ios_style.dart';
import '../../widgets/settings_group.dart';

/// Returned by the picker when the user wants another Google account.
const switchGoogleAccountResult = ['__switch_google_account__'];

/// Which Google calendars to import from [accountEmail]
/// (GoogleCalendarPickerView.swift): an iOS sheet with Cancel, a switch per
/// calendar and Import selected. Null when cancelled.
Future<List<String>?> showGoogleCalendarPickerSheet({
  required BuildContext context,
  required List<GoogleCalendarInfo> calendars,
  required List<String> initiallySelected,
  String? accountEmail,
}) {
  return showAppSheet<List<String>>(
    context,
    builder: (_) => _GoogleCalendarPickerBody(
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
    // The saved calendars ("primary" stands for the account's primary
    // calendar); the primary calendar when nothing is saved.
    final saved = widget.initiallySelected.toSet();
    _selected = {
      for (final c in widget.calendars)
        if (saved.contains(c.id) || (c.primary && saved.contains('primary')))
          c.id,
    };
    if (_selected.isEmpty) {
      _selected.addAll(
        widget.calendars.where((c) => c.primary).map((c) => c.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final secondary = IosColors.secondary(context);
    return Column(
      children: [
        SheetBar(
          title: lang.translate('choose_calendars'),
          leading: BarTextButton(
            key: const Key('google_picker_cancel'),
            label: lang.translate('cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Text(
                      lang.translate('choose_calendars_help'),
                      style: TextStyle(
                        fontSize: IosText.footnote,
                        color: secondary,
                      ),
                    ),
                  ),
                  if (widget.accountEmail != null) ...[
                    const SettingsSeparator(),
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_circle_outlined,
                            size: 20,
                            color: IosColors.teal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.accountEmail!,
                              key: const Key('google_picker_account'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: IosText.subheadline,
                                color: IosColors.primary(context),
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('google_switch_account'),
                            onPressed: () => Navigator.pop(
                              context,
                              switchGoogleAccountResult,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: IosColors.teal,
                            ),
                            child: Text(
                              lang.translate('switch_google_account'),
                              style: const TextStyle(
                                fontSize: IosText.subheadline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SettingsCard(
                children: [
                  for (final (index, c) in widget.calendars.indexed) ...[
                    if (index > 0) const SettingsSeparator(),
                    _calendarRow(c, lang),
                  ],
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('import_selected'),
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, [
                        for (final c in widget.calendars)
                          if (_selected.contains(c.id)) c.id,
                      ]),
                style: IosButtons.prominent(vertical: 15),
                child: Text(
                  lang.translate('import_selected'),
                  style: IosButtons.label,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _calendarRow(GoogleCalendarInfo c, LanguageService lang) {
    void toggle(bool on) => setState(() {
      if (on) {
        _selected.add(c.id);
      } else {
        _selected.remove(c.id);
      }
    });
    return InkWell(
      onTap: () => toggle(!_selected.contains(c.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.summary,
                    style: TextStyle(
                      fontSize: IosText.body,
                      color: IosColors.primary(context),
                    ),
                  ),
                  if (c.primary)
                    Text(
                      lang.translate('primary_calendar'),
                      style: TextStyle(
                        fontSize: IosText.caption,
                        color: IosColors.secondary(context),
                      ),
                    ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
              child: Switch.adaptive(
                key: Key('google_calendar_${c.id}'),
                value: _selected.contains(c.id),
                activeTrackColor: IosColors.googleBlue,
                onChanged: toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
