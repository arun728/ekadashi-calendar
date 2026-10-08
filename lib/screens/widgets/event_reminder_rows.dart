import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_language.dart';
import '../../models/calendar_entry.dart';
import '../../services/language_service.dart';
import '../../services/notifications/event_reminder_service.dart';
import '../../services/notifications/event_reminders.dart';
import '../../services/search/search_text.dart';
import '../../widgets/glass_tube.dart';
import '../premium_screen.dart';

typedef UpgradeAction = Future<void> Function(BuildContext context);

Future<void> _openPremium(BuildContext context) => openPremium(context);

String _language(BuildContext context) =>
    context.watch<LanguageService>().currentLocale.languageCode;

/// "On the day", "1 day before", "3 days before".
String _lead(int days, String language) => switch (days) {
  0 => AppStrings.translate('notifications_lead_0', language),
  1 => AppStrings.translate('notifications_lead_1', language),
  _ => AppStrings.translateWithArgs('notifications_lead_n', language, [
    '$days',
  ]),
};

/// "1 day before, 2 days before · 7:00 AM".
String _summary(BuildContext context, EventReminder reminder, String language) {
  final days = reminder.daysBefore.map((d) => _lead(d, language)).join(', ');
  final time = TimeOfDay(
    hour: reminder.hour,
    minute: reminder.minute,
  ).format(context);
  return '$days · $time';
}

IconData _icon(EventReminderTarget target) => switch (target.source) {
  null => Icons.auto_awesome,
  CalendarEntrySource.google => Icons.event_available,
  CalendarEntrySource.custom => Icons.calendar_today,
};

/// The "Festivals and events" part of Notifications (docs/ROADMAP.md
/// Phase 7): the user's reminders and a button to add one. Festival and
/// Panchang reminders are Premium (like Key days); reminders for the user's
/// own and Google entries are free. Mirrors the iOS EventReminderRows.
class EventReminderRows extends StatelessWidget {
  const EventReminderRows({
    super.key,
    required this.service,
    required this.enabled,
    required this.premium,
    this.onUpgrade = _openPremium,
  });

  final EventReminderService service;

  /// The master Notifications switch (and permission).
  final bool enabled;
  final bool premium;
  final UpgradeAction onUpgrade;

  void _edit(BuildContext context, EventReminder? original) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventReminderEditor(
          service: service,
          original: original,
          premium: premium,
          onUpgrade: onUpgrade,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = _language(context);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final reminders = service.reminders;
        return Column(
          children: [
            if (reminders.isEmpty)
              ListTile(
                enabled: enabled,
                title: Text(
                  AppStrings.translate('notifications_no_events', language),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            for (final reminder in reminders)
              ListTile(
                key: Key('event_reminder_row_${reminder.id}'),
                enabled: enabled,
                leading: Icon(
                  _icon(reminder.target),
                  color: GlassTubeColors.teal,
                ),
                title: Text(
                  EventReminderChoice.titleFor(reminder.target, language),
                ),
                subtitle: Text(
                  _summary(context, reminder, language),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reminder.target.requiresPremium && !premium)
                      Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.grey,
                        semanticLabel: AppStrings.translate(
                          'search_premium_locked',
                          language,
                        ),
                      ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () => _edit(context, reminder),
              ),
            ListTile(
              key: const Key('notifications_add_event'),
              enabled: enabled,
              leading: Icon(
                Icons.add_circle,
                color: enabled ? GlassTubeColors.teal : Colors.grey,
              ),
              title: Text(
                AppStrings.translate('notifications_add_event', language),
                style: TextStyle(
                  color: enabled ? GlassTubeColors.teal : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _edit(context, null),
            ),
          ],
        );
      },
    );
  }
}

/// Adds or edits one reminder: the event, the days before and the time.
class EventReminderEditor extends StatefulWidget {
  const EventReminderEditor({
    super.key,
    required this.service,
    required this.original,
    required this.premium,
    this.onUpgrade = _openPremium,
  });

  final EventReminderService service;
  final EventReminder? original;
  final bool premium;
  final UpgradeAction onUpgrade;

  @override
  State<EventReminderEditor> createState() => _EventReminderEditorState();
}

class _EventReminderEditorState extends State<EventReminderEditor> {
  EventReminderTarget? _target;
  late Set<int> _days;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final reminder =
        widget.original ??
        EventReminder(
          target: const EventReminderTarget.calendar(
            CalendarEntrySource.custom,
          ),
        );
    _target = widget.original?.target;
    _days = {...reminder.daysBefore};
    _time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
  }

  bool get _locked => _target?.requiresPremium == true && !widget.premium;

  Future<void> _choose() async {
    final picked = await Navigator.of(context).push<EventReminderTarget>(
      MaterialPageRoute(
        builder: (_) =>
            EventReminderPicker(selection: _target, premium: widget.premium),
      ),
    );
    if (picked != null && mounted) setState(() => _target = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  /// Saves even while locked: the reminder starts with Premium.
  Future<void> _save() async {
    final target = _target;
    if (target == null || _days.isEmpty) return;
    final original = widget.original;
    if (original != null && original.target != target) {
      await widget.service.remove(original.target);
    }
    await widget.service.upsert(
      EventReminder(
        target: target,
        daysBefore: _days.toList(),
        hour: _time.hour,
        minute: _time.minute,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.service.remove(widget.original!.target);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final language = _language(context);
    String t(String key) => AppStrings.translate(key, language);
    final target = _target;
    final canSave = target != null && _days.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: t('cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          t(
            widget.original == null
                ? 'notifications_add_event'
                : 'notifications_edit_event',
          ),
        ),
        actions: [
          TextButton(
            key: const Key('event_reminder_save'),
            onPressed: canSave ? _save : null,
            child: Text(t('save')),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            key: const Key('event_reminder_choose'),
            title: Text(t('notifications_choose_event')),
            subtitle: Text(
              target == null
                  ? '—'
                  : EventReminderChoice.titleFor(target, language),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _choose,
          ),
          const Divider(),
          _Header(t('notifications_lead_title')),
          for (final lead in EventReminder.leadDays)
            ListTile(
              key: Key('event_reminder_lead_$lead'),
              selected: _days.contains(lead),
              selectedColor: GlassTubeColors.teal,
              title: Text(_lead(lead, language)),
              trailing: _days.contains(lead)
                  ? const Icon(Icons.check, color: GlassTubeColors.teal)
                  : null,
              onTap: () => setState(
                () =>
                    _days.contains(lead) ? _days.remove(lead) : _days.add(lead),
              ),
            ),
          if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                t('notifications_lead_required'),
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          const Divider(),
          ListTile(
            key: const Key('event_reminder_time'),
            title: Text(t('notifications_time')),
            trailing: Text(
              _time.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: _pickTime,
          ),
          if (_locked) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.grey),
              title: Text(t('notifications_premium_events')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                key: const Key('event_reminder_upgrade'),
                style: FilledButton.styleFrom(
                  backgroundColor: GlassTubeColors.teal,
                ),
                onPressed: () => widget.onUpgrade(context),
                child: Text(t('premium_upgrade')),
              ),
            ),
          ],
          if (widget.original != null) ...[
            const Divider(),
            TextButton(
              key: const Key('event_reminder_delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _delete,
              child: Text(t('notifications_delete_event')),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.grey),
    ),
  );
}

/// Festivals (alphabetical), monthly days and the user's calendars, with a
/// search field. Premium choices carry a lock for free users.
class EventReminderPicker extends StatefulWidget {
  const EventReminderPicker({
    super.key,
    required this.selection,
    required this.premium,
  });

  final EventReminderTarget? selection;
  final bool premium;

  @override
  State<EventReminderPicker> createState() => _EventReminderPickerState();
}

class _EventReminderPickerState extends State<EventReminderPicker> {
  String _query = '';

  /// Matches the title in the app language or in English.
  List<EventReminderChoice> _filtered(List<EventReminderChoice> choices) {
    final needle = SearchText.normalize(_query);
    if (needle.isEmpty) return choices;
    return choices
        .where(
          (c) =>
              SearchText.normalize(c.title).contains(needle) ||
              SearchText.normalize(
                EventReminderChoice.titleFor(c.target, 'en'),
              ).contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final language = _language(context);
    final choices = _filtered(EventReminderChoice.all(language));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.translate('notifications_choose_event', language),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('event_reminder_search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: AppStrings.translate(
                  'notifications_search_events',
                  language,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final group in EventReminderGroup.values)
                  if (choices.any((c) => c.group == group)) ...[
                    _Header(AppStrings.translate(group.titleKey, language)),
                    for (final choice in choices.where((c) => c.group == group))
                      ListTile(
                        key: Key('event_choice_${choice.id}'),
                        title: Text(choice.title),
                        trailing: widget.selection == choice.target
                            ? const Icon(
                                Icons.check,
                                color: GlassTubeColors.teal,
                              )
                            : choice.requiresPremium && !widget.premium
                            ? const Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.grey,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(choice.target),
                      ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
